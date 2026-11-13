import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/notifications/notification_rows.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:treepnet/notifications/view/notifications_page.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockUserRepository extends Mock implements UserRepository {}

final _today = DateTime(2026, 11, 13, 18);

NotificationItem _like(String who, String post, {DateTime? at}) =>
    NotificationItem(
      type: NotificationType.like,
      actorId: who,
      actorUsername: who,
      postId: post,
      createdAt: at ?? _today,
    );

void main() {
  group('notificationRows', () {
    test("a post's likes of one day are one row, where the newest was", () {
      final comment = NotificationItem(
        type: NotificationType.comment,
        actorId: 'c',
        actorUsername: 'c',
        postId: 'p1',
        createdAt: _today,
      );
      final rows = notificationRows([
        _like('anna', 'p1'),
        comment,
        _like('bob', 'p1'),
        _like('dan', 'p2'),
        _like('eve', 'p1'),
      ]);
      expect([for (final r in rows) r.item.actorId], ['anna', 'c', 'dan']);
      expect([for (final r in rows) r.others], [2, 0, 0]);
    });

    test('another day is another row', () {
      final rows = notificationRows([
        _like('anna', 'p1'),
        _like('bob', 'p1', at: _today.subtract(const Duration(days: 1))),
      ]);
      expect(rows, hasLength(2));
    });

    test('the same person twice counts once', () {
      final rows = notificationRows([
        _like('anna', 'p1'),
        _like('bob', 'p1'),
        _like('bob', 'p1'),
      ]);
      expect(rows.single.others, 1);
    });

    test('follows and likes without a post or time stay as they are', () {
      final rows = notificationRows([
        const NotificationItem(
          type: NotificationType.follow,
          actorId: 'f',
          actorUsername: 'f',
        ),
        const NotificationItem(
          type: NotificationType.like,
          actorId: 'x',
          actorUsername: 'x',
          postId: 'p1',
        ),
        const NotificationItem(
          type: NotificationType.like,
          actorId: 'y',
          actorUsername: 'y',
          postId: 'p1',
        ),
      ]);
      expect(rows, hasLength(3));
    });
  });

  group('NotificationsPage', () {
    late _MockUserRepository repo;
    late _MockAppBloc app;
    var watched = 0;

    setUp(() {
      watched = 0;
      repo = _MockUserRepository();
      app = _MockAppBloc();
      when(() => app.state).thenReturn(
        const AppState.authenticated(User(id: 'me')),
      );
      when(
        () => repo.travelTierOf(userId: any(named: 'userId')),
      ).thenAnswer((_) => Stream.value(0));
      when(() => repo.notificationsOf(userId: 'me')).thenAnswer((_) {
        watched++;
        return Stream.value([
          _like('anna', 'p1', at: DateTime.now()),
          _like('bob', 'p1', at: DateTime.now()),
          _like('dan', 'p1', at: DateTime.now()),
          NotificationItem(
            type: NotificationType.comment,
            actorId: 'c',
            actorUsername: 'c',
            postId: 'p1',
            content: 'long ' * 200,
            createdAt: DateTime.now(),
          ),
        ]);
      });
    });

    Widget page({ThemeMode mode = ThemeMode.light}) =>
        BlocProvider<AppBloc>.value(
          value: app,
          child: RepositoryProvider<UserRepository>.value(
            value: repo,
            child: MaterialApp(
              themeMode: mode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const NotificationsPage(),
            ),
          ),
        );

    testWidgets('likes grouped; a long comment takes two lines at most', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      await tester.pump();

      expect(find.text('anna'), findsOneWidget);
      expect(find.text('bob'), findsNothing);
      expect(find.text('And 2 others liked your post.'), findsOneWidget);

      final comment = tester.widget<Text>(
        find.textContaining('Left a comment on your post'),
      );
      expect(comment.maxLines, 2);
      expect(comment.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
      'notifications off: the list starts with the way to turn them on, '
      'gone once allowed',
      (tester) async {
        addTearDown(() => PushNotifications.allowedForTest = null);
        PushNotifications.allowedForTest = false;
        await tester.pumpWidget(page());
        await tester.pump();
        expect(find.text('Turn on notifications'), findsOneWidget);
        expect(find.text('anna'), findsOneWidget, reason: 'the list stays');

        PushNotifications.allowedForTest = true;
        await tester.pump();
        expect(find.text('Turn on notifications'), findsNothing);
      },
    );

    testWidgets('not known yet: nothing is offered', (tester) async {
      PushNotifications.allowedForTest = null;
      await tester.pumpWidget(page());
      await tester.pump();
      expect(find.text('Turn on notifications'), findsNothing);
    });

    testWidgets('a rebuild keeps the list: the query is made once', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      await tester.pump();
      await tester.pumpWidget(page(mode: ThemeMode.dark));
      await tester.pump();

      expect(watched, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

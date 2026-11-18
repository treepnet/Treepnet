import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed_mode.dart';
import 'package:treepnet/feed/post/video/widgets/video_player_inherited_widget.dart';
import 'package:treepnet/feed/widgets/feed_tabs.dart';
import 'package:treepnet/feed/widgets/feed_top_bar.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockUserRepository extends Mock implements UserRepository {}

/// The switch at the feed's top left: the usual feed or the new one (a
/// prototype). Kept on the phone; the usual feed's videos stay quiet behind
/// the new one.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeedModeStore.mode.value = FeedMode.classic;
  });

  group('FeedModeStore', () {
    test('the usual feed until another is picked', () async {
      await FeedModeStore.load();
      expect(FeedModeStore.mode.value, FeedMode.classic);
    });

    test('the pick is kept for next time', () async {
      await FeedModeStore.set(FeedMode.globe);
      FeedModeStore.mode.value = FeedMode.classic; // the app starts again
      await FeedModeStore.load();
      expect(FeedModeStore.mode.value, FeedMode.globe);
    });
  });

  group('FeedTabsVideoGate', () {
    test('the usual feed’s videos stop behind the new feed', () {
      final state = VideoPlayerState();
      final gate = FeedTabsVideoGate(state)..modeChanged(classic: false);
      expect(state.shouldPlayFeed.value, isFalse);
      state.playFeed(); // e.g. the bottom bar
      expect(state.shouldPlayFeed.value, isFalse);

      gate.modeChanged(classic: true);
      expect(state.shouldPlayFeed.value, isTrue);
      // Back to the usual feed, but on Stories: still quiet.
      gate.tabChanged(1);
      expect(state.shouldPlayFeed.value, isFalse);
      gate.dispose();
    });
  });

  group('the switch', () {
    // The bell beside the switch reads the account and its unread count.
    final app = _MockAppBloc();
    final users = _MockUserRepository();
    setUpAll(() {
      whenListen(
        app,
        const Stream<AppState>.empty(),
        initialState: const AppState.authenticated(User(id: 'me')),
      );
      when(
        () => users.unreadNotificationsCount(userId: any(named: 'userId')),
      ).thenAnswer((_) => Stream.value(0));
    });

    Future<List<FeedMode>> pump(WidgetTester tester, {required int tab}) async {
      final picked = <FeedMode>[];
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [BlocProvider<AppBloc>.value(value: app)],
          child: RepositoryProvider<UserRepository>.value(
            value: users,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: FeedTopBar(
                  currentTab: tab,
                  onTabChanged: (_) {},
                  onFeedModeChanged: picked.add,
                ),
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    testWidgets(
      'on Posts, at the left; a tap on the globe picks the new feed',
      (tester) async {
        final picked = await pump(tester, tab: 0);
        final switcher = find.byType(FeedModeSwitch);
        expect(switcher, findsOneWidget);
        // Left of the Posts tab, not over it.
        expect(
          tester.getRect(switcher).right,
          lessThan(tester.getRect(find.text('Posts')).left),
        );
        await tester.tap(find.bySemanticsLabel('New feed'));
        expect(picked, [FeedMode.globe]);
      },
    );

    testWidgets('not on Stories, and the tabs stay where they were', (
      tester,
    ) async {
      await pump(tester, tab: 0);
      final postsOnPosts = tester.getRect(find.text('Posts'));
      await pump(tester, tab: 1);
      expect(find.byType(FeedModeSwitch), findsNothing);
      expect(tester.getRect(find.text('Posts')), postsOnPosts);
    });

    testWidgets('a narrow phone: the switch still clear of the tabs', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, tab: 0);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(FeedModeSwitch)).right,
        lessThanOrEqualTo(tester.getRect(find.text('Posts')).left),
      );
    });
  });
}

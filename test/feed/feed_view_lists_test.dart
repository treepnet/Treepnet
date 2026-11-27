import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/feed_mode.dart';
import 'package:treepnet/feed/new_feed/feed_globe_mode.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

import '../helpers/powersync_test_db.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockFeedBloc extends MockBloc<FeedEvent, FeedState>
    implements FeedBloc {}

class _MockPowerSync extends Mock implements PowerSyncRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockUploadQueue extends Mock implements MediaUploadQueue {}

/// The Posts tab's two lists, the usual feed and the new one: each is built
/// the first time it is picked, then kept behind the other; the new feed
/// knows whether it is on screen (a grown card's video plays only then).
void main() {
  late _MockAppBloc app;
  late _MockFeedBloc feed;
  late _MockPowerSync powerSync;
  late _MockUserRepository users;
  late _MockPostsRepository posts;
  late _MockUploadQueue uploads;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FeedModeStore.mode.value = FeedMode.classic;
    app = _MockAppBloc();
    feed = _MockFeedBloc();
    powerSync = _MockPowerSync();
    users = _MockUserRepository();
    posts = _MockPostsRepository();
    uploads = _MockUploadQueue();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    whenListen(
      feed,
      const Stream<FeedState>.empty(),
      initialState: const FeedState.initial(),
    );
    // Offline and not synced yet: a real, empty, never-connected database.
    final db = await openTestPowerSyncDb();
    when(() => powerSync.db()).thenReturn(db);
    when(
      () => users.unreadNotificationsCount(userId: any(named: 'userId')),
    ).thenAnswer((_) => Stream.value(0));
    when(() => uploads.status).thenReturn(ValueNotifier(null));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>.value(value: app),
          BlocProvider<FeedBloc>.value(value: feed),
        ],
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PowerSyncRepository>.value(value: powerSync),
            RepositoryProvider<UserRepository>.value(value: users),
            RepositoryProvider<PostsRepository>.value(value: posts),
            RepositoryProvider<MediaUploadQueue>.value(value: uploads),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: FeedView(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The lists built (the one behind included), the usual feed's first
  /// (false), then the new one (true).
  List<bool> built(WidgetTester tester) => [
    for (final body in tester.widgetList<FeedBody>(
      find.byType(FeedBody, skipOffstage: false),
    ))
      body.globe,
  ];

  FeedGlobeMode globeMode(WidgetTester tester) => tester.widget<FeedGlobeMode>(
    find.byType(FeedGlobeMode, skipOffstage: false),
  );

  /// Past the switch's slide and the lists' loading shimmer frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets('the usual feed: the new one is not built at all', (
    tester,
  ) async {
    await pump(tester);
    expect(built(tester), [false]);
    expect(find.byType(FeedGlobeMode, skipOffstage: false), findsNothing);
    await settle(tester);
  });

  testWidgets('the new feed picked: built, on screen; kept when left', (
    tester,
  ) async {
    await pump(tester);
    FeedModeStore.mode.value = FeedMode.globe;
    await settle(tester);
    expect(built(tester), [false, true]);
    expect(globeMode(tester).onScreen?.value, isTrue);

    FeedModeStore.mode.value = FeedMode.classic;
    await settle(tester);
    expect(built(tester), [false, true], reason: 'kept where it was');
    expect(globeMode(tester).onScreen?.value, isFalse);
  });

  testWidgets('opening on the new feed: the usual one not built', (
    tester,
  ) async {
    // Picked before (kept on the phone), restored at start-up.
    SharedPreferences.setMockInitialValues({'treepnet_feed_mode': 'globe'});
    FeedModeStore.mode.value = FeedMode.globe;
    await pump(tester);
    expect(built(tester), [true]);
    expect(globeMode(tester).onScreen?.value, isTrue);
    await settle(tester);
  });

  test('the feed picked before, read at start-up', () async {
    SharedPreferences.setMockInitialValues({'treepnet_feed_mode': 'globe'});
    FeedModeStore.restore(await SharedPreferences.getInstance());
    expect(FeedModeStore.mode.value, FeedMode.globe);
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase, SyncStatus;
import 'package:powersync_repository/powersync_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/timeline/timeline.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockTimelineBloc extends MockBloc<TimelineEvent, TimelineState>
    implements TimelineBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockPowerSync extends Mock implements PowerSyncRepository {}

class _MockDb extends Mock implements PowerSyncDatabase {}

/// Trends' Maps and Posts tabs: a swipe left or right goes from one to the
/// other, as the feed's Posts and Stories; a tap on a tab's name slides
/// there.
void main() {
  late _MockAppBloc app;
  late _MockTimelineBloc timeline;
  late _MockPostsRepository posts;
  late _MockPowerSync powerSync;

  setUp(() {
    app = _MockAppBloc();
    timeline = _MockTimelineBloc();
    posts = _MockPostsRepository();
    powerSync = _MockPowerSync();
    final db = _MockDb();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    // Still loading: both tabs show their placeholders.
    whenListen(
      timeline,
      const Stream<TimelineState>.empty(),
      initialState: const TimelineState.initial(),
    );
    when(() => powerSync.db()).thenReturn(db);
    // ignore: invalid_use_of_internal_member
    when(() => db.currentStatus).thenReturn(const SyncStatus());
    when(() => db.statusStream).thenAnswer((_) => const Stream.empty());
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>.value(value: app),
          BlocProvider<TimelineBloc>.value(value: timeline),
        ],
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PostsRepository>.value(value: posts),
            RepositoryProvider<PowerSyncRepository>.value(value: powerSync),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: TimelineView(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  int shownTab(WidgetTester tester) =>
      tester.widget<TrendsTopBar>(find.byType(TrendsTopBar)).currentTab;

  /// Past the slide (the placeholders shimmer for ever, so never settled).
  Future<void> slide(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a swipe left goes to Posts, a swipe right back to Maps', (
    tester,
  ) async {
    await pump(tester);
    expect(shownTab(tester), TrendsTopBar.maps);
    final page = tester.getRect(find.byType(PageView));

    await tester.flingFrom(page.center, const Offset(-400, 0), 1500);
    await slide(tester);
    expect(shownTab(tester), TrendsTopBar.posts);

    await tester.flingFrom(page.center, const Offset(400, 0), 1500);
    await slide(tester);
    expect(shownTab(tester), TrendsTopBar.maps);
  });

  testWidgets("a tap on a tab's name slides there", (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('trendsPostsTab')));
    await slide(tester);
    expect(shownTab(tester), TrendsTopBar.posts);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);

    await tester.tap(find.byKey(const ValueKey('trendsMapsTab')));
    await slide(tester);
    expect(shownTab(tester), TrendsTopBar.maps);
  });
}

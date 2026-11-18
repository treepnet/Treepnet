import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' show TimeAgo;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/feed/new_feed/feed_post_steps.dart';
import 'package:treepnet/feed/post/post.dart' show PostView;
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/timeline/timeline.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockTimelineBloc extends MockBloc<TimelineEvent, TimelineState>
    implements TimelineBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

/// Trends' header and its Maps tab: Trends' posts in Trends' order, each on
/// its author's globe as in the new feed.
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
    registerFallbackValue(const TimelinePageRequested());
  });

  Widget app(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );

  group('the header', () {
    testWidgets('Maps and Posts, as the feed has Posts and Stories; the '
        'search at the right', (tester) async {
      final picked = <int>[];
      await tester.pumpWidget(
        app(
          TrendsTopBar(currentTab: TrendsTopBar.maps, onTabChanged: picked.add),
        ),
      );
      expect(find.text('Maps'), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      // Maps first, Posts after it.
      expect(
        tester.getCenter(find.text('Maps')).dx,
        lessThan(tester.getCenter(find.text('Posts')).dx),
      );
      expect(find.byType(TimelineSearchButton), findsOneWidget);
      final screen = tester.getSize(find.byType(Scaffold));
      expect(
        tester.getRect(find.byType(TimelineSearchButton)).right,
        closeTo(screen.width, 0.5),
      );
      await tester.tap(find.text('Posts'));
      await tester.tap(find.text('Maps'));
      expect(picked, [TrendsTopBar.posts, TrendsTopBar.maps]);
    });
  });

  group('the Maps tab', () {
    late _MockAppBloc appBloc;
    late _MockTimelineBloc timeline;
    late _MockPostsRepository posts;
    late _MockUserRepository users;
    late _MockStoriesRepository stories;
    late StreamController<TimelineState> states;

    PostLargeBlock post(String id, String author) => PostLargeBlock(
      id: id,
      author: PostAuthor(id: author, avatarUrl: '', username: author),
      createdAt: DateTime(2026),
      media: const [ImageMedia(id: 'm', url: '')],
      caption: 'caption $id',
    );

    // Trends' order (its rating): a's three, then b's two, then c's.
    final trending = [
      post('a1', 'a'),
      post('a2', 'a'),
      post('a3', 'a'),
      post('b1', 'b'),
      post('b2', 'b'),
      post('c1', 'c'),
    ];

    TimelineState shown(List<PostBlock> blocks, {bool hasMore = false}) =>
        const TimelineState.initial().copyWith(
          status: TimelineStatus.populated,
          timeline: FeedPage(
            blocks: blocks,
            totalBlocks: blocks.length,
            page: 1,
            hasMore: hasMore,
          ),
        );

    setUp(() {
      appBloc = _MockAppBloc();
      timeline = _MockTimelineBloc();
      posts = _MockPostsRepository();
      users = _MockUserRepository();
      stories = _MockStoriesRepository();
      states = StreamController<TimelineState>.broadcast();
      addTearDown(states.close);
      whenListen(
        appBloc,
        const Stream<AppState>.empty(),
        initialState: const AppState.authenticated(User(id: 'me')),
      );
      when(
        () => posts.statsOf(postId: any(named: 'postId')),
      ).thenAnswer((_) => const Stream<PostStats>.empty());
      when(
        () => posts.travelMapOf(userId: any(named: 'userId')),
      ).thenAnswer((_) async => null);
      when(
        () => users.travelTierOf(userId: any(named: 'userId')),
      ).thenAnswer((_) => const Stream<int>.empty());
      when(
        () => stories.mergedStories(
          authorId: any(named: 'authorId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) => const Stream<List<Story>>.empty());
    });

    Future<ScrollController> pump(
      WidgetTester tester,
      TimelineState state, {
      int seed = 1,
    }) async {
      whenListen(timeline, states.stream, initialState: state);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AppBloc>.value(value: appBloc),
            BlocProvider<TimelineBloc>.value(value: timeline),
          ],
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<PostsRepository>.value(value: posts),
              RepositoryProvider<UserRepository>.value(value: users),
              RepositoryProvider<StoriesRepository>.value(value: stories),
            ],
            // Narrow: short globes, a few posts at once.
            child: app(
              Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 160,
                  child: TimelineMapsView(
                    scrollController: scroll,
                    random: math.Random(seed),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return scroll;
    }

    /// The globes' own delayed work run out (a globe built in the last frame
    /// starts its own).
    Future<void> settleGlobes(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    /// The posts down the list (no finger scroll: by its controller), each
    /// as it is built.
    Future<List<String>> cards(
      WidgetTester tester,
      ScrollController scroll,
    ) async {
      final ids = <String>[];
      void note() {
        for (final globe in tester.widgetList<FeedPostGlobe>(
          find.byType(FeedPostGlobe),
        )) {
          if (!ids.contains(globe.block.id)) ids.add(globe.block.id);
        }
      }

      note();
      // A step at a time (a jump to the end would skip the middle).
      for (var i = 0; i < 60; i++) {
        final position = scroll.position;
        if (position.pixels >= position.maxScrollExtent) break;
        scroll.jumpTo(
          math.min(position.pixels + 150, position.maxScrollExtent),
        );
        await tester.pump();
        note();
      }
      scroll.jumpTo(0);
      await tester.pump();
      return ids;
    }

    for (var seed = 0; seed < 20; seed++) {
      testWidgets("Trends' posts, mixed: never one person's two in a row "
          '(dice $seed)', (tester) async {
        final scroll = await pump(tester, shown(trending), seed: seed);
        final ids = await cards(tester, scroll);
        // Every post, none twice.
        expect(ids, unorderedEquals(trending.map((post) => post.id)));
        // Not Trends' rating order: no one's posts side by side.
        for (var i = 1; i < ids.length; i++) {
          expect(
            ids[i][0],
            isNot(ids[i - 1][0]),
            reason: '${ids[i - 1]} then ${ids[i]} in $ids',
          );
        }
        await settleGlobes(tester);
      });
    }

    testWidgets('a next page mixes in after the posts already there', (
      tester,
    ) async {
      final scroll = await pump(tester, shown(trending, hasMore: true));
      final before = await cards(tester, scroll);
      states.add(
        shown([...trending, post('d1', 'd'), post('a4', 'a')], hasMore: true),
      );
      await tester.pump();
      final after = await cards(tester, scroll);
      expect(after.take(before.length), before, reason: 'none moves');
      expect(after.skip(before.length), unorderedEquals(['d1', 'a4']));
      await settleGlobes(tester);
    });

    testWidgets('a post gone from Trends goes; the rest keep their places', (
      tester,
    ) async {
      final scroll = await pump(tester, shown(trending));
      final before = await cards(tester, scroll);
      states.add(shown(trending.where((post) => post.id != 'b1').toList()));
      await tester.pump();
      expect(await cards(tester, scroll), before.where((id) => id != 'b1'));
      await settleGlobes(tester);
    });

    testWidgets('the arrows alone under each post; only down under the first', (
      tester,
    ) async {
      await pump(tester, shown(trending));
      final steps = tester.widgetList<FeedPostSteps>(
        find.byType(FeedPostSteps),
      );
      expect(steps.first.first, isTrue);
      expect(find.byType(FeedPostPlace), findsNothing);
      // No description either (the grid's posts keep theirs).
      expect(find.textContaining('caption '), findsNothing);
      final list = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
      await settleGlobes(tester);
    });

    testWidgets("the down arrow under the globe's buttons, up beside it", (
      tester,
    ) async {
      final scroll = await pump(tester, shown(trending));
      // The second post (it has both arrows), its line under its globe.
      scroll.jumpTo(
        tester.getTopLeft(find.byType(FeedPostGlobe).at(1)).dy -
            tester.getTopLeft(find.byType(CustomScrollView)).dy,
      );
      await tester.pump();
      final post = find.ancestor(
        of: find.byType(FeedPostGlobe).first,
        matching: find.byType(PostView),
      );
      Finder inPost(Finder finder) =>
          find.descendant(of: post, matching: finder);
      final plus = tester.getCenter(inPost(find.byIcon(Icons.add)));
      final down = tester.getCenter(
        inPost(find.byKey(const ValueKey('feedPostDown'))),
      );
      final up = tester.getCenter(
        inPost(find.byKey(const ValueKey('feedPostUp'))),
      );
      // No time: the globe is about all the author's posts, not this one.
      expect(inPost(find.byType(TimeAgo)), findsNothing);
      // In the buttons' line, under them.
      expect(down.dx, closeTo(plus.dx, 0.5));
      expect(down.dy, greaterThan(plus.dy));
      // The up arrow to its left, level with it.
      expect(up.dx, lessThan(down.dx));
      expect(up.dy, closeTo(down.dy, 0.5));
      await settleGlobes(tester);
    });

    testWidgets('the end of the list asks for the next page', (tester) async {
      final scroll = await pump(tester, shown(trending, hasMore: true));
      for (var i = 0; i < 12; i++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
      // The loader asks a moment after it shows.
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => timeline.add(const TimelinePageRequested())).called(1);
      await settleGlobes(tester);
    });
  });
}

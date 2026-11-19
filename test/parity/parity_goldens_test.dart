// Pixel-parity baseline for the new feed and Trends (see docs in each
// group): golden images of every look the user designed, taken from the
// prototype, so a rebuild can prove it changed no pixel. Regenerate only on
// purpose: flutter test --update-goldens test/parity.
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart'
    show BlurHashImageThumbnail;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed_mode.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/post/post.dart' show PostView;
import 'package:treepnet/feed/widgets/feed_top_bar.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/search/view/search_page.dart';
import 'package:treepnet/timeline/timeline.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockTimelineBloc extends MockBloc<TimelineEvent, TimelineState>
    implements TimelineBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

class _MockSearchRepository extends Mock implements SearchRepository {}

const _author = PostAuthor(id: 'author', avatarUrl: '', username: 'traveller');

String _image(String name) => 'file:///parity-missing/$name.jpg';

PostLargeBlock _post(
  String id, {
  String caption = '',
  String? location = 'Tashkent',
  Duration age = const Duration(hours: 2),
}) => PostLargeBlock(
  id: id,
  author: _author,
  // Relative to now, so "2 hours ago" reads the same whenever this runs.
  createdAt: DateTime.now().subtract(age),
  // Files, not URLs: a network image would reach for the cache's plugins,
  // which a test has none of (a missing file just shows the blur).
  media: [ImageMedia(id: 'm-$id', url: _image(id))],
  caption: caption,
  location: location,
);

const _short = 'Sunrise over the old city';
const _long =
    'We walked from the Registan to Shah-i-Zinda at dawn, before the tour '
    'buses came, and the blue tiles of every dome caught the first light one '
    'after another while the city was still asleep.';

/// The author's globe: Tashkent (this post), Samarkand, Istanbul, Mumbai
/// (their other posts, with photos), and a story pin.
const _map = TravelMap(
  regions: {'UZ-TK': 2, 'UZ-SA': 1, 'TR-34': 1, 'IN-MH': 1},
  pins: [
    (
      postId: 'post-1',
      lat: 41.36,
      lng: 69.23,
      name: 'Magic City',
      thumb: 'file:///parity-missing/thumb1.jpg',
    ),
    (
      postId: 'post-2',
      lat: 39.65,
      lng: 66.96,
      name: null,
      thumb: 'file:///parity-missing/thumb2.jpg',
    ),
    (
      postId: 'post-3',
      lat: 41.01,
      lng: 28.97,
      name: null,
      thumb: 'file:///parity-missing/thumb3.jpg',
    ),
    (
      postId: 'post-4',
      lat: 19.07,
      lng: 72.88,
      name: null,
      thumb: 'file:///parity-missing/thumb4.jpg',
    ),
    (postId: null, lat: 40.1, lng: 65.4, name: 'Story', thumb: null),
  ],
);

void main() {
  late _MockAppBloc app;
  late _MockTimelineBloc timeline;
  late _MockPostsRepository posts;
  late _MockUserRepository users;
  late _MockStoriesRepository stories;
  late _MockSearchRepository search;

  setUpAll(() async {
    await initializeDateFormatting();
    // The map data in before any globe draws, so every golden has its land
    // and borders whatever order the tests run in — and every level of
    // detail of it built, so none lands late (a busy machine) and leaves a
    // coarser stand-in in a picture.
    await GeoRegions.instance.load();
    await GlobeView.debugBuildAllLevels();
  });

  setUp(() {
    // The globes remember opened pins in the phone's preferences.
    SharedPreferences.setMockInitialValues({});
    app = _MockAppBloc();
    timeline = _MockTimelineBloc();
    posts = _MockPostsRepository();
    users = _MockUserRepository();
    stories = _MockStoriesRepository();
    search = _MockSearchRepository();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    when(
      () => posts.statsOf(postId: any(named: 'postId')),
    ).thenAnswer((_) => const Stream<PostStats>.empty());
    when(
      () => posts.travelMapOf(userId: any(named: 'userId')),
    ).thenAnswer((_) async => _map);
    when(
      () => posts.postRemovals,
    ).thenAnswer((_) => const Stream<PostRemoval>.empty());
    when(
      () => users.travelTierOf(userId: any(named: 'userId')),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(
      () => users.unreadNotificationsCount(userId: any(named: 'userId')),
    ).thenAnswer((_) => Stream.value(0));
    when(() => users.suggestedUsers(limit: any(named: 'limit'))).thenAnswer(
      (_) async => [
        for (var i = 0; i < 30; i++)
          User(id: 'u$i', username: 'traveller$i', fullName: 'Traveller $i'),
      ],
    );
    when(
      () => stories.mergedStories(
        authorId: any(named: 'authorId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => const Stream<List<Story>>.empty());
  });

  final shot = GlobalKey();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 440,
    double height = 1100,
    bool dark = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AppBloc>.value(value: app),
          BlocProvider<TimelineBloc>.value(value: timeline),
        ],
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PostsRepository>.value(value: posts),
            RepositoryProvider<UserRepository>.value(value: users),
            RepositoryProvider<StoriesRepository>.value(value: stories),
            RepositoryProvider<SearchRepository>.value(value: search),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? const AppDarkTheme().theme : const AppTheme().theme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: shot,
                  // The app's ground under it, as on the phone.
                  child: Builder(
                    builder: (context) => ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The travel map, then the globe's first laid-out frame.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  /// The globes' own delayed work run out (and their growing settled).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  Future<void> golden(WidgetTester tester, String name) async {
    await expectLater(find.byKey(shot), matchesGoldenFile('goldens/$name.png'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Finder photo(String id) =>
      find.byWidgetPredicate((w) => w is BlurHashImageThumbnail && w.id == id);

  GlobeController controllerOf(WidgetTester tester) =>
      tester.widget<GlobeView>(find.byType(GlobeView)).controller!;

  group('the new feed — its card on the globe', () {
    Widget globe(double width, {PostLargeBlock? block}) => SizedBox(
      width: width,
      child: FeedGlobeMode(
        child: FeedPostGlobe(
          block: block ?? _post('post-1', caption: _short),
          isLiked: true,
          likesCount: 12,
          commentsCount: 3,
        ),
      ),
    );

    for (final width in [320.0, 440.0]) {
      testWidgets('small, on its pin, ${width.toInt()} wide', (tester) async {
        await pump(tester, globe(width));
        await settle(tester);
        await golden(tester, 'card_small_${width.toInt()}');
      });
    }

    testWidgets('grown', (tester) async {
      await pump(tester, globe(440));
      await settle(tester);
      await tester.tap(photo('post-1'));
      await settle(tester);
      await golden(tester, 'card_grown_440');
    });

    testWidgets('following its pin as the globe turns', (tester) async {
      await pump(tester, globe(440));
      await settle(tester);
      controllerOf(tester).moveTo(41.36, 99.23);
      await settle(tester);
      await golden(tester, 'card_turned_440');
    });

    testWidgets('no place name: no label in the corner', (tester) async {
      await pump(tester, globe(440, block: _post('post-1', location: null)));
      await settle(tester);
      await golden(tester, 'card_no_place_440');
    });
  });

  group("Trends' Maps — the photos on the pins", () {
    Widget globe(double width) => SizedBox(
      width: width,
      child: FeedGlobeMode(
        style: FeedGlobeStyle.photos,
        child: FeedPostGlobe(block: _post('post-1')),
      ),
    );

    for (final width in [320.0, 440.0]) {
      testWidgets('small, ${width.toInt()} wide', (tester) async {
        await pump(tester, globe(width));
        await settle(tester);
        await golden(tester, 'photos_small_${width.toInt()}');
      });
    }

    testWidgets('grown', (tester) async {
      await pump(tester, globe(440));
      await settle(tester);
      await tester.tapAt(tester.getCenter(photo('post-1')));
      await settle(tester);
      await golden(tester, 'photos_grown_440');
    });

    testWidgets('zoomed in: neighbours come apart', (tester) async {
      await pump(tester, globe(440));
      await settle(tester);
      controllerOf(tester).moveTo(40.5, 68, zoom: 6);
      await settle(tester);
      await golden(tester, 'photos_zoomed_440');
    });
  });

  group('a whole post', () {
    Widget list(List<Widget> children, {required double width}) => SizedBox(
      width: width,
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [SliverList.list(children: children)],
      ),
    );

    for (final (name, caption, index) in [
      ('short', _short, 1),
      ('long', _long, 1),
      ('none', '', 1),
      ('first', _short, 0),
    ]) {
      for (final dark in [true, false]) {
        testWidgets('the new feed: $name description '
            '(${dark ? 'dark' : 'light'})', (tester) async {
          await pump(
            tester,
            list(width: 440, [
              FeedGlobeMode(
                child: PostView(
                  block: _post('post-1', caption: caption),
                  postIndex: index,
                ),
              ),
            ]),
            dark: dark,
          );
          await settle(tester);
          await golden(tester, 'post_feed_${name}_${dark ? 'dark' : 'light'}');
        });
      }
    }

    for (final dark in [true, false]) {
      testWidgets("Trends' Maps (${dark ? 'dark' : 'light'})", (tester) async {
        await pump(
          tester,
          list(width: 440, [
            FeedGlobeMode(
              style: FeedGlobeStyle.photos,
              child: PostView(
                block: _post('post-1', caption: _long),
                postIndex: 1,
              ),
            ),
          ]),
          dark: dark,
        );
        await settle(tester);
        await golden(tester, 'post_trends_${dark ? 'dark' : 'light'}');
      });
    }

    for (final dark in [true, false]) {
      testWidgets('the usual feed (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await pump(
          tester,
          list(width: 440, [
            PostView(
              block: _post('post-1', caption: _long),
              postIndex: 1,
              // No in-view list around it here (the feed's plays videos).
              withInViewNotifier: false,
            ),
          ]),
          dark: dark,
        );
        await settle(tester);
        await golden(tester, 'post_classic_${dark ? 'dark' : 'light'}');
      });
    }
  });

  group('the bars', () {
    for (final (tab, mode) in [
      (0, FeedMode.classic),
      (0, FeedMode.globe),
      (1, FeedMode.classic),
    ]) {
      for (final width in [320.0, 440.0]) {
        testWidgets('the feed bar: tab $tab, ${mode.name}, '
            '${width.toInt()} wide', (tester) async {
          FeedModeStore.mode.value = mode;
          addTearDown(() => FeedModeStore.mode.value = FeedMode.classic);
          await pump(
            tester,
            SizedBox(
              width: width,
              child: FeedTopBar(
                currentTab: tab,
                onTabChanged: (_) {},
                onFeedModeChanged: (_) {},
              ),
            ),
            width: width,
            height: 200,
          );
          await golden(tester, 'bar_feed_${tab}_${mode.name}_${width.toInt()}');
        });
      }
    }

    for (final tab in [TrendsTopBar.maps, TrendsTopBar.posts]) {
      testWidgets('the Trends bar: tab $tab', (tester) async {
        await pump(
          tester,
          SizedBox(
            width: 440,
            child: TrendsTopBar(currentTab: tab, onTabChanged: (_) {}),
          ),
          height: 200,
        );
        await golden(tester, 'bar_trends_$tab');
      });
    }
  });

  group("Trends' Maps — the list", () {
    testWidgets('mixed, the arrows only', (tester) async {
      final blocks = [
        _post('a1'),
        _post('a2'),
        PostLargeBlock(
          id: 'b1',
          author: const PostAuthor(id: 'b', avatarUrl: '', username: 'b'),
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
          media: [ImageMedia(id: 'm', url: _image('b1'))],
          caption: 'b',
        ),
      ];
      whenListen(
        timeline,
        const Stream<TimelineState>.empty(),
        initialState: const TimelineState.initial().copyWith(
          status: TimelineStatus.populated,
          timeline: FeedPage(
            blocks: blocks,
            totalBlocks: blocks.length,
            page: 1,
            hasMore: false,
          ),
        ),
      );
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pump(
        tester,
        SizedBox(
          width: 440,
          height: 1100,
          child: TimelineMapsView(
            scrollController: scroll,
            random: math.Random(7),
          ),
        ),
      );
      await settle(tester);
      await golden(tester, 'trends_maps_list');
    });
  });

  group('search', () {
    testWidgets('nothing typed: the suggestions', (tester) async {
      await pump(
        tester,
        const SizedBox(width: 440, height: 1100, child: SearchView()),
      );
      await settle(tester);
      await golden(tester, 'search_suggestions');
    });
  });
}

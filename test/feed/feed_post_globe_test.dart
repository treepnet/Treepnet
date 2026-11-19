import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/post_pin_card.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart';
import 'package:user_repository/user_repository.dart';

import 'helpers/globe_harness.dart';

final _post = globePost;

/// The author's other posts' photos on their pins.
final _others = find.byWidgetPredicate((w) => w is OtherPinPhoto);

/// This post's photo (on its pin, or grown).
Finder _photo() => find.byWidgetPredicate(
  (w) => w is BlurHashImageThumbnail && w.id == 'post-1',
);

/// Trends' Maps tab (a prototype): each post's author's globe, 4:5, facing
/// the post's place, the post's small photo on its pin and the author's
/// other posts' on theirs (FeedGlobeMode.photosOnPins). The new feed's
/// card: feed_post_globe_card_test.dart.
void main() {
  late GlobeHarness harness;
  late MockPostsRepository posts;
  late MockAppBloc app;
  late MockUserRepository users;

  setUp(() {
    harness = GlobeHarness();
    posts = harness.posts;
    app = harness.app;
    users = harness.users;
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      harness.pump(tester, child, style: FeedGlobeStyle.photos);

  testWidgets('4:5, facing the post, turned and zoomed as on the profile', (
    tester,
  ) async {
    await pump(
      tester,
      SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
    );
    await tester.pump();
    final size = tester.getSize(find.byType(FeedPostGlobe));
    expect(size.height / size.width, closeTo(5 / 4, 0.01));
    final globe = tester.widget<GlobeView>(find.byType(GlobeView));
    // On the post's meridian, turned a little off it (room for the card
    // over the pin).
    final center = globe.initialCenter!;
    expect(center.lng, 69.23);
    expect(center.lat, lessThan(41.36 + 15.01));
    expect(center.lat, greaterThan(41.36 - 20.01));
    expect(globe.claimTap, isNotNull);
    expect(globe.controller, isNotNull);
    // Its +, − and back buttons, drawn over the photos (see below).
    expect(globe.showButtons, isFalse);
    expect(find.byType(GlobeButtons), findsOneWidget);
    expect(globe.visitedCounts, {'UZ-TK': 1});
    // The globe's own delayed work (its region labels) runs out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag over the globe turns it, not the feed', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pump(
      tester,
      ListView(
        controller: scroll,
        children: [
          FeedPostGlobe(block: _post),
          const SizedBox(height: 2000),
        ],
      ),
    );
    await tester.pump();
    final globe = tester.widget<GlobeView>(find.byType(GlobeView));
    final before = globe.controller!.center;
    // Beside the card, on the globe (the card is in the middle, across).
    final globeBox = tester.getRect(find.byType(GlobeView));
    await tester.dragFrom(
      globeBox.topLeft + const Offset(40, 300),
      const Offset(-200, 0),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(scroll.offset, 0);
    expect(globe.controller!.center.lng, isNot(closeTo(before.lng, 1)));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("+, − and back to the post's place, as on the profile", (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    final globe = tester.widget<GlobeView>(find.byType(GlobeView));
    final controller = globe.controller!;
    final opening = controller.center;
    final zoom = controller.zoom;

    /// The globe's flight, frame by frame (it steps per frame).
    Future<void> fly() async {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await tester.tap(find.byIcon(Icons.add));
    await fly();
    expect(controller.zoom, greaterThan(zoom + 0.5));

    await tester.tap(find.byIcon(Icons.remove));
    await fly();
    expect(controller.zoom, closeTo(zoom, 0.1));

    // Turned away, then back to where it opened: the post's place.
    controller.moveTo(10, 10, zoom: zoom + 3);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.my_location));
    await fly();
    await fly();
    expect(controller.center.lat, closeTo(opening.lat, 0.01));
    expect(controller.center.lng, closeTo(opening.lng, 0.01));
    expect(controller.zoom, closeTo(zoom, 0.1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the card goes round with the pin, and away behind it', (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    final controller = tester
        .widget<GlobeView>(find.byType(GlobeView))
        .controller!;
    const spot = (lat: 41.36, lng: 69.23);
    final box = tester.getRect(find.byType(FeedPostGlobe));

    void expectOnPin() {
      final at = box.topLeft + controller.pinAt(spot)!;
      final photo = tester.getRect(_photo());
      expect(photo.center.dx, closeTo(at.dx, 0.5));
      expect(photo.bottom, closeTo(at.dy - GlobeView.pinIconTop - 2, 0.5));
    }

    expectOnPin();
    // Turned east: the pin, and the card, go west of the middle.
    controller.moveTo(41.36, 99.23);
    await tester.pump();
    expect(controller.pinAt(spot)!.dx, lessThan(box.width / 2 - 40));
    expectOnPin();

    // Round the back: no card.
    controller.moveTo(-41.36, -110.77);
    await tester.pump();
    expect(controller.pinAt(spot), isNull);
    expect(find.byType(BlurHashImageThumbnail), findsNothing);

    // Back in front: the card again.
    controller.moveTo(41.36, 69.23);
    await tester.pump();
    expectOnPin();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag over a small photo turns the globe under it', (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    final controller = tester
        .widget<GlobeView>(find.byType(GlobeView))
        .controller!;
    final before = controller.center;
    await tester.dragFrom(tester.getCenter(_photo()), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.center.lng, isNot(closeTo(before.lng, 1)));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("the globe's +, − and back buttons over the photos", (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    // Drawn by the post, not under the globe's own: above the photos layer.
    final globe = tester.widget<GlobeView>(find.byType(GlobeView));
    expect(globe.showButtons, isFalse);
    final stack = tester.widget<Stack>(
      find
          .ancestor(of: find.byType(GlobeButtons), matching: find.byType(Stack))
          .first,
    );
    final children = stack.children;
    int indexOf(Type type) => children.indexWhere(
      (child) => find
          .descendant(of: find.byWidget(child), matching: find.byType(type))
          .evaluate()
          .isNotEmpty,
    );
    expect(indexOf(GlobeButtons), greaterThan(indexOf(GlobeView)));
    final photos = children.indexWhere(
      (child) => find
          .descendant(of: find.byWidget(child), matching: _photo())
          .evaluate()
          .isNotEmpty,
    );
    expect(indexOf(GlobeButtons), greaterThan(photos));
    await tester.pump(const Duration(seconds: 1));
  });

  for (final (name, lat, lng, width) in [
    ('Tashkent', 41.36, 69.23, 300.0),
    ('Sydney', -33.87, 151.21, 300.0),
    ('Tashkent, 440 wide', 41.36, 69.23, 440.0),
  ]) {
    testWidgets('the post, its photo alone, small, on its pin — $name', (
      tester,
    ) async {
      when(() => posts.travelMapOf(userId: 'author')).thenAnswer(
        (_) async => TravelMap(
          regions: const {},
          pins: [
            (postId: 'post-1', lat: lat, lng: lng, name: null, thumb: null),
          ],
        ),
      );
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: FeedPostGlobe(block: _post),
          ),
        ),
      );
      await tester.pump();
      final box = tester.getRect(find.byType(FeedPostGlobe));
      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      // Facing the post's place: its pin in the middle.
      expect(globe.initialCenter, (lat: lat, lng: lng));
      expect(globe.padding, EdgeInsets.zero);

      // The photo just over the pin's icon, small (a sixth of the width).
      final photo = tester.getRect(_photo());
      expect(photo.center.dx, closeTo(box.center.dx, 0.5));
      expect(
        photo.bottom,
        closeTo(box.center.dy - GlobeView.pinIconTop - 2, 0.5),
      );
      expect(photo.height, photo.width);
      expect(photo.width, closeTo((width * 0.17).clamp(52, 76), 0.5));
      // The photo alone: no buttons, no grey under it.
      expect(find.byKey(const ValueKey('pinCardLike')), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets("the author's other posts on their pins at once", (tester) async {
    when(() => posts.travelMapOf(userId: 'author')).thenAnswer(
      (_) async => const TravelMap(
        regions: {},
        pins: [
          (
            postId: 'post-1',
            lat: 41.36,
            lng: 69.23,
            name: null,
            thumb: 'https://p/1.jpg',
          ),
          // Istanbul and Mumbai: far enough to show on the whole globe.
          (
            postId: 'post-2',
            lat: 41.01,
            lng: 28.97,
            name: null,
            thumb: 'https://p/2.jpg',
          ),
          (
            postId: 'post-3',
            lat: 19.07,
            lng: 72.88,
            name: null,
            thumb: 'https://p/3.jpg',
          ),
          // Samarkand: next to Tashkent on the whole globe, under its photo;
          // its own once zoomed in.
          (
            postId: 'post-7',
            lat: 39.65,
            lng: 66.96,
            name: null,
            thumb: 'https://p/7.jpg',
          ),
          // On this post's own spot: under its photo, not shown.
          (
            postId: 'post-4',
            lat: 41.36,
            lng: 69.23,
            name: null,
            thumb: 'https://p/4.jpg',
          ),
          // No photo (from before 041), and a story pin: none.
          (postId: 'post-5', lat: 37.2, lng: 67.3, name: null, thumb: null),
          (postId: null, lat: 40.1, lng: 65.4, name: null, thumb: null),
          // Round the back of the globe: none.
          (
            postId: 'post-6',
            lat: -20,
            lng: -110,
            name: null,
            thumb: 'https://p/6.jpg',
          ),
        ],
      ),
    );
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 440, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    await tester.pump();
    final controller = tester
        .widget<GlobeView>(find.byType(GlobeView))
        .controller!;
    final box = tester.getRect(find.byType(FeedPostGlobe));
    final urls = tester
        .widgetList<BlurHashImageThumbnail>(
          find.descendant(
            of: _others,
            matching: find.byType(BlurHashImageThumbnail),
          ),
        )
        .map((thumb) => thumb.url)
        .toList();
    expect(urls, unorderedEquals(['https://p/2.jpg', 'https://p/3.jpg']));
    // Each on its own pin.
    for (final (i, spot) in [
      (2, (lat: 41.01, lng: 28.97)),
      (3, (lat: 19.07, lng: 72.88)),
    ]) {
      final at = box.topLeft + controller.pinAt(spot)!;
      final photo = tester.getRect(
        find.ancestor(
          of: find.byWidgetPredicate(
            (w) => w is BlurHashImageThumbnail && w.url == 'https://p/$i.jpg',
          ),
          matching: _others,
        ),
      );
      expect(photo.center.dx, closeTo(at.dx, 0.5));
      expect(photo.bottom, closeTo(at.dy - GlobeView.pinIconTop - 2, 0.5));
    }
    // This post's own photo is there too.
    expect(_photo(), findsOneWidget);

    // A tap on another's photo grows it, with that post's own buttons.
    when(() => posts.getPostBy(id: 'post-2')).thenAnswer(
      (_) async => Post(
        id: 'post-2',
        createdAt: DateTime(2026),
        author: const User(id: 'author', username: 'author'),
        caption: 'Istanbul',
        media: const [
          ImageMedia(
            id: 'm2',
            url: 'https://p/2-full.jpg',
            thumbUrl: 'https://p/2.jpg',
          ),
        ],
      ),
    );
    when(
      () => posts.like(
        id: any(named: 'id'),
        liked: any(named: 'liked'),
      ),
    ).thenAnswer((_) async {});
    final istanbul = tester.getCenter(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) => w is BlurHashImageThumbnail && w.url == 'https://p/2.jpg',
        ),
        matching: _others,
      ),
    );
    await tester.tapAt(istanbul);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final grown = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is BlurHashImageThumbnail && w.id == 'post-2',
      ),
    );
    expect(grown.width, closeTo(440 - 24, 0.5));
    // The post itself came in: its full photo.
    expect(
      find.byWidgetPredicate(
        (w) => w is BlurHashImageThumbnail && w.url == 'https://p/2-full.jpg',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('pinCardLike')));
    await tester.pump();
    verify(() => posts.like(id: 'post-2')).called(1);
    // A tap off it shrinks it back onto its pin.
    await tester.tapAt(const Offset(780, 580));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('pinCardLike')), findsNothing);

    // Zoomed in over Uzbekistan: Samarkand comes out from under it.
    controller.moveTo(40.5, 68, zoom: 6);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is BlurHashImageThumbnail && w.url == 'https://p/7.jpg',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('like and comment counts on the grown card', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: FeedPostGlobe(block: _post, likesCount: 12, commentsCount: 3),
      ),
    );
    await tester.pump();
    await tester.tap(_photo());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pinCardLike')),
        matching: find.text('12'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('pinCardComment')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('how far they have travelled, in the top left corner', (
    tester,
  ) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      ),
    );
    await tester.pump();
    final count = find.text('1 country · 1 region');
    expect(count, findsOneWidget);
    final box = tester.getRect(find.byType(FeedPostGlobe));
    final badge = tester.getRect(
      find.ancestor(of: count, matching: find.byType(Container)).first,
    );
    expect(badge.topLeft, box.topLeft + const Offset(8, 8));
    // The card stands below it.
    final photo = tester.getRect(find.byType(BlurHashImageThumbnail));
    expect(photo.top, greaterThan(badge.bottom));
    // Over the card when the globe takes the card under it: drawn last.
    final stack = tester.widget<Stack>(
      find
          .ancestor(
            of: find.byType(TravelCountBadge),
            matching: find.byType(Stack),
          )
          .first,
    );
    final last = stack.children.last;
    expect(last, isA<Positioned>());
    expect((last as Positioned).child, isA<TravelCountBadge>());
    await tester.pump(const Duration(seconds: 1));
  });

  group('a tap on the card', () {
    /// Past the card's growing or shrinking (the photo loads for ever in a
    /// test, so nothing ever settles).
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    Rect photo(WidgetTester tester) =>
        tester.getRect(find.byType(BlurHashImageThumbnail));

    /// The globe in a feed, its card grown.
    Future<({List<String> taps, ScrollController scroll})> grow(
      WidgetTester tester,
    ) async {
      final taps = <String>[];
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await pump(
        tester,
        globeList(scroll, [
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: FeedPostGlobe(
                block: _post,
                onLikeTap: () => taps.add('like'),
                onShareTap: (_) => taps.add('share'),
                onCommentsTap: (_) => taps.add('comment'),
                onSaveTap: () => taps.add('save'),
              ),
            ),
          ),
          const SizedBox(height: 2000),
        ]),
      );
      await tester.pump();
      expect(photo(tester).width, closeTo(52, 0.5));
      await tester.tap(find.byType(BlurHashImageThumbnail));
      await settle(tester);
      return (taps: taps, scroll: scroll);
    }

    testWidgets('grows it in its place, across the globe; nothing else '
        'changes', (tester) async {
      await grow(tester);
      final box = tester.getRect(find.byType(FeedPostGlobe));
      final big = photo(tester);
      expect(big.width, closeTo(300 - 24, 0.5));
      expect(big.height, big.width);
      expect(big.center.dx, closeTo(box.center.dx, 0.5));
      final save = tester.getRect(find.byKey(const ValueKey('pinCardSave')));
      expect(
        Rect.fromLTRB(big.left, big.top, big.right, save.bottom).center.dy,
        closeTo(box.center.dy, 0.5),
      );
      // Still the one card, in the post: no layer over the feed.
      expect(
        find.descendant(
          of: find.byType(FeedPostGlobe),
          matching: find.byKey(const ValueKey('pinCardLike')),
        ),
        findsOneWidget,
      );
      expect(find.byType(BlurHashImageThumbnail), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a scroll of the feed (an arrow) shrinks it back', (
      tester,
    ) async {
      final (:taps, :scroll) = await grow(tester);
      unawaited(
        scroll.animateTo(
          300,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        ),
      );
      // The scroll, then the shrink it sets off.
      await settle(tester);
      await settle(tester);
      expect(scroll.offset, 300, reason: 'the feed scrolls');
      expect(photo(tester).width, closeTo(52, 0.5));
      expect(taps, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a jump of the feed (its top bar) shrinks it too', (
      tester,
    ) async {
      final (taps: _, :scroll) = await grow(tester);
      scroll.jumpTo(50);
      await settle(tester);
      expect(photo(tester).width, closeTo(52, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the buttons row is the feed switch grey', (tester) async {
      await grow(tester);
      final grounds = tester
          .widgetList<DecoratedBox>(
            find.ancestor(
              of: find.byKey(const ValueKey('pinCardLike')),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => (box.decoration as BoxDecoration).color);
      expect(grounds, contains(AppColors.inputSpace));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a tap anywhere off it shrinks it back', (tester) async {
      await grow(tester);
      await tester.tapAt(const Offset(780, 580));
      await settle(tester);
      expect(photo(tester).width, closeTo(52, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('another tap on its photo shrinks it back', (tester) async {
      await grow(tester);
      await tester.tap(find.byType(BlurHashImageThumbnail));
      await settle(tester);
      expect(photo(tester).width, closeTo(52, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('its buttons come as it grows; on the pin, none', (
      tester,
    ) async {
      await pump(
        tester,
        SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('pinCardLike')), findsNothing);
      await tester.tap(_photo());
      await settle(tester);
      expect(find.byKey(const ValueKey('pinCardLike')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('its buttons work with it big, at once, and leave it big', (
      tester,
    ) async {
      final (:taps, scroll: _) = await grow(tester);
      for (final key in ['Like', 'Share', 'Comment', 'Save']) {
        await tester.tap(find.byKey(ValueKey('pinCard$key')));
        // At once, with no wait for a second tap.
        expect(taps.last, key.toLowerCase());
        await tester.pump();
      }
      expect(taps, ['like', 'share', 'comment', 'save']);
      await settle(tester);
      expect(photo(tester).width, closeTo(276, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('a tap on a pin', () {
    /// On a router, as in the app: the place's page is a route.
    Future<void> pumpRouted(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: FeedGlobeMode(
                style: FeedGlobeStyle.photos,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 300,
                    child: FeedPostGlobe(block: _post),
                  ),
                ),
              ),
            ),
            routes: [
              GoRoute(
                name: AppRoutes.locationPosts.name,
                path: 'location-posts',
                builder: (context, state) {
                  final q = state.uri.queryParameters;
                  return Scaffold(
                    body: Text(
                      'place ${q['userId']} ${q['iso']} ${q['scope']} '
                      '${q['place']} ${q['lat']}',
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [BlocProvider<AppBloc>.value(value: app)],
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<PostsRepository>.value(value: posts),
              RepositoryProvider<UserRepository>.value(value: users),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    final tashkent = TravelMapTarget(
      region: GeoRegion(
        iso: 'UZ-TK',
        name: 'Tashkent',
        countryCode: 'UZ',
        countryName: 'Uzbekistan',
        rings: const [],
      ),
      point: (lat: 41.36, lng: 69.23, name: 'City'),
    );

    testWidgets("opens the author's posts there, as on their profile", (
      tester,
    ) async {
      await pumpRouted(tester);
      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      globe.onTargetTap!(tashkent);
      await tester.pumpAndSettle();
      expect(find.text('place author UZ-TK point City 41.36'), findsOneWidget);
    });

    testWidgets('not when the tap was on a photo', (tester) async {
      await pumpRouted(tester);
      // The globe hears a tap on the photo too, a moment later.
      await tester.tapAt(tester.getCenter(_photo()));
      await tester.pump();
      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      globe.onTargetTap!(tashkent);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('place '), findsNothing);
      // The photo's tap grew its card instead.
      expect(find.byKey(const ValueKey('pinCardLike')), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

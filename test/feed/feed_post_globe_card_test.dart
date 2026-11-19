import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
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
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

final _post = PostLargeBlock(
  id: 'post-1',
  author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
  createdAt: DateTime(2026),
  media: const [ImageMedia(id: 'm1', url: '')],
  caption: '',
);

/// The small card's arrow (on the post's pin).
final _arrow = find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString() == '_ArrowPainter',
);

/// The new feed (a prototype), its card (FeedGlobeMode's default; Trends'
/// photos: feed_post_globe_test.dart): each post's author's globe, 4:5, facing the
/// post's place, with a small card of the post on its pin — a picture the
/// feed scrolls over.
void main() {
  late _MockAppBloc app;
  late _MockPostsRepository posts;

  setUp(() {
    app = _MockAppBloc();
    posts = _MockPostsRepository();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    when(() => posts.travelMapOf(userId: 'author')).thenAnswer(
      (_) async => const TravelMap(
        regions: {'UZ-TK': 1},
        pins: [
          (postId: 'post-1', lat: 41.36, lng: 69.23, name: 'City', thumb: null),
        ],
      ),
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider<AppBloc>.value(value: app)],
      child: RepositoryProvider<PostsRepository>.value(
        value: posts,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: child),
        ),
      ),
    ),
  );

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
    expect(globe.interactive, isTrue);
    expect(globe.controller, isNotNull);
    expect(globe.showButtons, isTrue);
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
      final arrow = tester.getRect(_arrow);
      expect(arrow.center.dx, closeTo(at.dx, 0.5));
      expect(arrow.bottom, closeTo(at.dy - GlobeView.pinIconTop - 2, 0.5));
      final photo = tester.getRect(find.byType(BlurHashImageThumbnail));
      expect(photo.center.dx, closeTo(at.dx, 0.5));
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
    expect(_arrow, findsNothing);

    // Back in front: the card again.
    controller.moveTo(41.36, 69.23);
    await tester.pump();
    expectOnPin();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a drag over the small card scrolls the feed too', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pump(
      tester,
      ListView(
        controller: scroll,
        children: [
          FeedPostGlobe(block: _post, onLikeTap: () {}),
          const SizedBox(height: 2000),
        ],
      ),
    );
    await tester.pump();
    await tester.drag(
      find.byType(BlurHashImageThumbnail),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(scroll.offset, greaterThan(100));
    await tester.pump(const Duration(seconds: 1));
  });

  /// Where [globe] draws a pin at [lat] on its meridian (orthographic), in
  /// a [box] panel.
  double pinYOf(Rect box, GlobeView globe, double lat) {
    final r = GlobeView.wholeGlobeRadius(box.size);
    return box.center.dy -
        r * math.sin((lat - globe.initialCenter!.lat) * math.pi / 180);
  }

  for (final (name, lat, lng, width) in [
    ('Tashkent', 41.36, 69.23, 300.0),
    ('Sydney', -33.87, 151.21, 300.0),
    // A wide phone: room to raise the pin, so the card's top is 8% down.
    ('Tashkent, 440 wide', 41.36, 69.23, 440.0),
  ]) {
    testWidgets('the post, small, standing on its pin — $name', (tester) async {
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
      // Turned so the pin sits a little off the middle: above it on a wide
      // phone, a little below on a narrow one.
      expect(globe.initialCenter!.lng, lng);
      expect(globe.initialCenter!.lat, lessThan(lat + 15.01));
      expect(globe.initialCenter!.lat, greaterThan(lat - 20.01));
      expect(globe.padding, EdgeInsets.zero);

      // Its arrow on the pin, just over the pin's icon.
      final arrow = tester.getRect(_arrow);
      expect(arrow.center.dx, closeTo(box.center.dx, 0.5));
      expect(
        arrow.bottom,
        closeTo(pinYOf(box, globe, lat) - GlobeView.pinIconTop - 2, 0.5),
      );

      // The card over it, a third of the width, inside the globe's box.
      final photo = tester.getRect(find.byType(BlurHashImageThumbnail));
      final save = tester.getRect(find.byKey(const ValueKey('pinCardSave')));
      expect(photo.width, lessThanOrEqualTo(box.width * 0.35));
      expect(photo.height, photo.width);
      expect(photo.center.dx, closeTo(box.center.dx, 0.5));
      expect(photo.top, greaterThanOrEqualTo(box.top));
      expect(save.bottom, closeTo(arrow.top, 0.6));
      if (width == 440) {
        expect(photo.top, closeTo(box.top + box.height * 0.08, 0.6));
        expect(globe.initialCenter!.lat, lessThan(lat));
      } else {
        // Too narrow to raise the pin: the card clear of the travel count,
        // the pin a little below the middle.
        expect(photo.top, closeTo(box.top + 44, 0.6));
        expect(globe.initialCenter!.lat, greaterThan(lat));
      }
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('like and comment counts on the card', (tester) async {
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: FeedPostGlobe(block: _post, likesCount: 12, commentsCount: 3),
      ),
    );
    await tester.pump();
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
        ListView(
          controller: scroll,
          children: [
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
          ],
        ),
      );
      await tester.pump();
      expect(photo(tester).width, closeTo(102, 0.5));
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

    testWidgets('a scroll of the feed shrinks it back', (tester) async {
      final (:taps, :scroll) = await grow(tester);
      await tester.dragFrom(const Offset(780, 300), const Offset(0, -200));
      await settle(tester);
      expect(scroll.offset, greaterThan(100), reason: 'the feed scrolls');
      expect(photo(tester).width, closeTo(102, 0.5));
      expect(taps, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a drag over the big card scrolls the feed and shrinks it', (
      tester,
    ) async {
      final (:taps, :scroll) = await grow(tester);
      await tester.drag(
        find.byType(BlurHashImageThumbnail),
        const Offset(0, -150),
      );
      await settle(tester);
      expect(scroll.offset, greaterThan(100));
      expect(photo(tester).width, closeTo(102, 0.5));
      expect(taps, isEmpty);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a jump of the feed (its top bar) shrinks it too', (
      tester,
    ) async {
      final (taps: _, :scroll) = await grow(tester);
      scroll.jumpTo(50);
      await settle(tester);
      expect(photo(tester).width, closeTo(102, 0.5));
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
      expect(photo(tester).width, closeTo(102, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('another tap on its photo shrinks it back', (tester) async {
      await grow(tester);
      await tester.tap(find.byType(BlurHashImageThumbnail));
      await settle(tester);
      expect(photo(tester).width, closeTo(102, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('its buttons work with it big, and leave it big', (
      tester,
    ) async {
      final (:taps, scroll: _) = await grow(tester);
      for (final key in ['Like', 'Share', 'Comment', 'Save']) {
        await tester.tap(find.byKey(ValueKey('pinCard$key')));
        await tester.pump();
      }
      expect(taps, ['like', 'share', 'comment', 'save']);
      await settle(tester);
      expect(photo(tester).width, closeTo(276, 0.5));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets("the small card's buttons: like, share, comment, save", (
    tester,
  ) async {
    final taps = <String>[];
    await pump(
      tester,
      SizedBox(
        width: 300,
        child: FeedPostGlobe(
          block: _post,
          isLiked: true,
          onLikeTap: () => taps.add('like'),
          onShareTap: (_) => taps.add('share'),
          onCommentsTap: (_) => taps.add('comment'),
          onSaveTap: () => taps.add('save'),
        ),
      ),
    );
    await tester.pump();
    for (final key in ['Like', 'Share', 'Comment', 'Save']) {
      await tester.tap(find.byKey(ValueKey('pinCard$key')));
      // At once, with no wait for a second tap.
      expect(taps.last, key.toLowerCase());
    }
    expect(taps, ['like', 'share', 'comment', 'save']);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets("its country and city on the globe, bottom left, level with "
      'the back-to-the-post button', (tester) async {
    final placed = PostLargeBlock(
      id: 'post-1',
      author: _post.author,
      createdAt: DateTime(2026),
      media: _post.media,
      caption: '',
      location: 'Tashkent',
    );
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: placed)),
      ),
    );
    await tester.pump();
    final box = tester.getRect(find.byType(FeedPostGlobe));
    final place = find.descendant(
      of: find.byType(FeedPostGlobe),
      matching: find.byType(FeedPostPlace),
    );
    expect(place, findsOneWidget);
    expect(find.text('Tashkent'), findsOneWidget);
    final back = tester.getCenter(find.byIcon(Icons.my_location));
    final line = tester.getRect(place);
    expect(line.left, closeTo(box.left + 8, 0.5));
    expect(line.center.dy, closeTo(back.dy, 0.5));
    // Clear of the buttons' column.
    expect(line.right, lessThan(tester.getRect(find.byIcon(Icons.add)).left));
    await tester.pump(const Duration(seconds: 1));
  });

  group('a tap on a pin', () {
    /// On a router, as in the app: the place's page is a route.
    Future<void> pumpRouted(WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: 300, child: FeedPostGlobe(block: _post)),
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
          child: RepositoryProvider<PostsRepository>.value(
            value: posts,
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
      expect(globe.onTargetTap, isNotNull);
      globe.onTargetTap!(tashkent);
      await tester.pumpAndSettle();
      expect(find.text('place author UZ-TK point City 41.36'), findsOneWidget);
    });

    testWidgets('not while the card is grown', (tester) async {
      await pumpRouted(tester);
      await tester.tap(find.byType(BlurHashImageThumbnail));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final globe = tester.widget<GlobeView>(find.byType(GlobeView));
      globe.onTargetTap!(tashkent);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('place '), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  test('only the new feed marks its posts', () {
    // FeedGlobeMode is what PostView reads; outside it, the photos.
    expect(
      const FeedGlobeMode(
        child: SizedBox(),
      ).updateShouldNotify(const FeedGlobeMode(child: SizedBox())),
      isFalse,
    );
  });
}

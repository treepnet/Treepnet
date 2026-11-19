import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/feed_globe_mode.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/post_pin_card.dart';
import 'package:treepnet/map/globe_view.dart';

import 'helpers/globe_harness.dart';

/// A post's globe and its author's map: a fetch that fails is tried again,
/// a new post missing from the map kept is asked for afresh, and a grown
/// video plays only while its list is on screen.
void main() {
  late GlobeHarness harness;

  setUp(() => harness = GlobeHarness());

  GlobeView globe(WidgetTester tester) =>
      tester.widget<GlobeView>(find.byType(GlobeView));

  /// Past the globe's own delayed work, and [time] more.
  Future<void> wait(WidgetTester tester, Duration time) async {
    await tester.pump();
    await tester.pump(time);
    await tester.pump();
  }

  testWidgets('a failed fetch: the globe bare, then its map from a retry', (
    tester,
  ) async {
    var calls = 0;
    when(() => harness.posts.travelMapOf(userId: 'author')).thenAnswer((
      _,
    ) async {
      if (calls++ == 0) throw Exception('offline');
      return tashkentMap;
    });
    await harness.pump(
      tester,
      SizedBox(width: 300, child: FeedPostGlobe(block: globePost)),
    );
    await wait(tester, const Duration(milliseconds: 100));
    // Bare meanwhile: no regions, no pin to open on.
    expect(globe(tester).visitedCounts, isEmpty);
    expect(globe(tester).faceTravels, isTrue);

    await wait(tester, const Duration(seconds: 3));
    expect(calls, 2);
    expect(globe(tester).visitedCounts, {'UZ-TK': 1});
    expect(globe(tester).initialCenter?.lng, 69.23, reason: 'on the post');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a new post not in the map kept: asked for afresh, on its pin', (
    tester,
  ) async {
    // Kept from before the post: its author's other pin only.
    when(() => harness.posts.travelMapOf(userId: 'author')).thenAnswer(
      (_) async => const TravelMap(
        regions: {'UZ-SA': 1},
        pins: [
          (postId: 'older', lat: 39.65, lng: 66.96, name: null, thumb: null),
        ],
      ),
    );
    when(
      () => harness.posts.travelMapOf(userId: 'author', fresh: true),
    ).thenAnswer((_) async => tashkentMap);
    final post = PostLargeBlock(
      id: 'post-1',
      author: globePost.author,
      createdAt: DateTime.now(),
      media: globePost.media,
      caption: '',
      location: 'Tashkent',
    );
    await harness.pump(
      tester,
      SizedBox(width: 300, child: FeedPostGlobe(block: post)),
    );
    await wait(tester, const Duration(milliseconds: 100));
    verify(
      () => harness.posts.travelMapOf(userId: 'author', fresh: true),
    ).called(1);
    expect(globe(tester).initialCenter?.lng, 69.23, reason: 'on the post');
    expect(globe(tester).visitedCounts, {'UZ-TK': 1});
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an older post not in the map: the map as kept, asked once', (
    tester,
  ) async {
    when(
      () => harness.posts.travelMapOf(userId: 'author'),
    ).thenAnswer((_) async => const TravelMap(regions: {}, pins: []));
    final post = PostLargeBlock(
      id: 'post-1',
      author: globePost.author,
      createdAt: DateTime(2024),
      media: globePost.media,
      caption: '',
      location: 'Somewhere',
    );
    await harness.pump(
      tester,
      SizedBox(width: 300, child: FeedPostGlobe(block: post)),
    );
    await wait(tester, const Duration(minutes: 2));
    verify(() => harness.posts.travelMapOf(userId: 'author')).called(1);
    verifyNever(() => harness.posts.travelMapOf(userId: 'author', fresh: true));
  });

  testWidgets('a grown card: its video waits while its list is off screen, '
      'still there', (tester) async {
    final onScreen = ValueNotifier(true);
    addTearDown(onScreen.dispose);
    await harness.pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: globePost)),
      ),
      onScreen: onScreen,
    );
    await wait(tester, const Duration(milliseconds: 100));
    await tester.tap(find.byType(BlurHashImageThumbnail));
    await wait(tester, const Duration(milliseconds: 500));
    PostPinCard card() => tester.widget<PostPinCard>(find.byType(PostPinCard));
    expect(card().big, isTrue);
    expect(card().playVideo, isTrue, reason: 'grown: its video on');
    expect(card().videoPaused, isFalse);

    // Another tab: the video waits (kept, not loaded again on the way back).
    onScreen.value = false;
    await tester.pump();
    expect(card().videoPaused, isTrue);
    expect(card().playVideo, isTrue);
    expect(card().big, isTrue, reason: 'still grown');

    onScreen.value = true;
    await tester.pump();
    expect(card().videoPaused, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a map that comes while a finger is on the globe waits for it', (
    tester,
  ) async {
    var calls = 0;
    when(() => harness.posts.travelMapOf(userId: 'author')).thenAnswer((
      _,
    ) async {
      if (calls++ == 0) throw Exception('offline');
      return tashkentMap;
    });
    await harness.pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: globePost)),
      ),
    );
    await wait(tester, const Duration(milliseconds: 100));
    // A finger on the bare globe, turning it, as the retry lands.
    final finger = await tester.startGesture(const Offset(40, 300));
    await finger.moveBy(const Offset(-30, 0));
    await wait(tester, const Duration(seconds: 3));
    expect(calls, 2);
    expect(globe(tester).visitedCounts, isEmpty, reason: 'not under it');
    await finger.moveBy(const Offset(-30, 0));
    await finger.up();
    await wait(tester, const Duration(milliseconds: 100));
    expect(globe(tester).visitedCounts, {'UZ-TK': 1});
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a card grown: a double tap on the globe still zooms it', (
    tester,
  ) async {
    await harness.pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: FeedPostGlobe(block: globePost)),
      ),
    );
    await wait(tester, const Duration(milliseconds: 100));
    await tester.tap(find.byType(BlurHashImageThumbnail));
    await wait(tester, const Duration(milliseconds: 500));
    final controller = globe(tester).controller!;
    final before = controller.zoom;
    // Off the grown card, on the globe: the first tap shrinks the card, the
    // second makes it a double tap.
    const at = Offset(6, 366);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(at);
    // The zoom eases in, frame by frame.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.zoom, greaterThan(before + 0.5));
    await tester.pump(const Duration(seconds: 1));
  });

  group('a screen too short for the whole post', () {
    testWidgets('the first post makes room for what is over it too', (
      tester,
    ) async {
      // The upload banner over the list's first post, 58 tall, then gone.
      final banner = ValueNotifier<double>(58);
      addTearDown(banner.dispose);
      await harness.pump(
        tester,
        ValueListenableBuilder<double>(
          valueListenable: banner,
          builder: (context, height, _) => CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: height)),
              SliverList.list(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 50),
                      SizedBox(
                        width: 300,
                        child: FeedPostGlobe(block: globePost),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        viewportHeight: 420,
        aboveFirstPost: banner,
      );
      await wait(tester, const Duration(milliseconds: 100));
      double height() => tester.getSize(find.byType(FeedPostGlobe)).height;
      expect(height(), 420 - (58 + 50) - 52);

      banner.value = 0;
      await wait(tester, const Duration(milliseconds: 100));
      expect(height(), 420 - 50 - 52);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the keyboard over the list is no short screen', (
      tester,
    ) async {
      final listHeight = GlobeListHeight();
      final seen = <double>[];
      Future<void> lay(double height) => tester.pumpWidget(
        Center(
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                seen.add(listHeight.of(context, constraints));
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await lay(600);
      // The keyboard comes up: the list's height shrinks, the globes' not.
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await lay(320);
      await lay(310);
      // It goes: the list's own height again.
      tester.view.resetViewInsets();
      await lay(600);
      await lay(500);
      expect(seen, [600, 600, 600, 600, 500]);
    });

    /// A post as a list has it: a 50-tall header over the globe.
    Widget post() => globeList(ScrollController(), [
      Column(
        children: [
          const SizedBox(height: 50),
          SizedBox(width: 300, child: FeedPostGlobe(block: globePost)),
        ],
      ),
    ]);

    double globeHeight(WidgetTester tester) =>
        tester.getSize(find.byType(FeedPostGlobe)).height;

    testWidgets('room for it: 4:5, as ever', (tester) async {
      await harness.pump(tester, post(), viewportHeight: 800);
      await wait(tester, const Duration(milliseconds: 100));
      expect(globeHeight(tester), 300 / (4 / 5));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('no room: shorter, its arrows on screen under it', (
      tester,
    ) async {
      await harness.pump(tester, post(), viewportHeight: 420);
      await wait(tester, const Duration(milliseconds: 100));
      // The header (50) over it, measured; under it the gap over the line
      // (8), its padding (4) and the arrows (40).
      expect(globeHeight(tester), 420 - 50 - 52);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

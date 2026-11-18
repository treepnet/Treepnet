import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/feed/new_feed/feed_post_steps.dart';

/// The new feed (a prototype): under each post, the down arrow to the next
/// post and, from the second post on, the up arrow to the one before.
void main() {
  // Posts of different heights, as a feed's are.
  const heights = [700.0, 520.0, 910.0, 640.0, 700.0];

  /// Where post [i] starts in the list.
  double topOf(int i) => heights.take(i).fold(0, (a, b) => a + b);

  Future<ScrollController> pump(WidgetTester tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              // Something above the posts (the upload banner).
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              SliverList.builder(
                itemCount: heights.length,
                itemBuilder: (context, i) => SizedBox(
                  key: ValueKey('post$i'),
                  height: heights[i],
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: FeedPostSteps(first: i == 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return scroll;
  }

  Finder inPost(int i, String button) => find.descendant(
    of: find.byKey(ValueKey('post$i')),
    matching: find.byKey(ValueKey(button)),
  );

  /// Scrolls so the buttons under post [i] are in the middle of the screen
  /// (600 high in a test).
  Future<void> showButtonsOf(
    WidgetTester tester,
    ScrollController scroll,
    int i,
  ) async {
    scroll.jumpTo(40 + topOf(i) + heights[i] - 300);
    await tester.pumpAndSettle();
  }

  testWidgets('the first post: only down; the ones after: up and down', (
    tester,
  ) async {
    final scroll = await pump(tester);
    expect(inPost(0, 'feedPostDown'), findsOneWidget);
    expect(inPost(0, 'feedPostUp'), findsNothing);
    await showButtonsOf(tester, scroll, 1);
    expect(inPost(1, 'feedPostDown'), findsOneWidget);
    expect(inPost(1, 'feedPostUp'), findsOneWidget);
  });

  testWidgets('the arrows alone, a little bigger, on nothing', (tester) async {
    await pump(tester);
    final arrow = tester.widget<Icon>(
      find.descendant(
        of: inPost(0, 'feedPostDown'),
        matching: find.byType(Icon),
      ),
    );
    expect(arrow.icon, Icons.keyboard_arrow_down_rounded);
    expect(arrow.size, 34);
    expect(arrow.color, Colors.white);
    // Nothing painted behind it (the tap's own box is see-through).
    final grounds = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: inPost(0, 'feedPostDown'),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => (box.decoration as BoxDecoration).color);
    for (final color in grounds) {
      expect(color == null || color.a == 0, isTrue, reason: '$color');
    }
  });

  testWidgets("down: the next post's top at the top of the list", (
    tester,
  ) async {
    final scroll = await pump(tester);
    await showButtonsOf(tester, scroll, 0);
    await tester.tap(inPost(0, 'feedPostDown'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(40 + topOf(1), 0.5));

    await showButtonsOf(tester, scroll, 1);
    await tester.tap(inPost(1, 'feedPostDown'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(40 + topOf(2), 0.5));
  });

  testWidgets("up: the post before's top at the top of the list", (
    tester,
  ) async {
    final scroll = await pump(tester);
    // Post 2 just above the screen: built.
    await showButtonsOf(tester, scroll, 3);
    await tester.tap(inPost(3, 'feedPostUp'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(40 + topOf(2), 0.5));

    // Post 1 far above (post 2 is 910 high): not built until it nears.
    await showButtonsOf(tester, scroll, 2);
    await tester.tap(inPost(2, 'feedPostUp'));
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(40 + topOf(1), 0.5));
  });

  testWidgets('the last post: down goes as far as the feed goes', (
    tester,
  ) async {
    final scroll = await pump(tester);
    await showButtonsOf(tester, scroll, 4);
    await tester.tap(inPost(4, 'feedPostDown'));
    await tester.pumpAndSettle();
    expect(scroll.offset, scroll.position.maxScrollExtent);
  });
}

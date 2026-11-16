import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_view/story_view.dart';
import 'package:treepnet/stories/view/stories_page.dart';

void main() {
  for (final watched in [true, false]) {
    testWidgets(
      'back to the previous profile opens its last story '
      '(${watched ? 'all watched' : 'none watched'})',
      (tester) async {
        final controller = StoryController();
        final items = [
          for (var i = 0; i < 3; i++)
            StoryItem(
              const SizedBox.expand(),
              duration: const Duration(seconds: 5),
              shown: watched,
            ),
        ];
        openOnLast(items);

        final shown = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            home: StoryView(
              storyItems: items,
              controller: controller,
              onStoryShow: (_, index) => shown.add(index),
            ),
          ),
        );
        expect(shown, [2]);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  testWidgets('a single story is opened', (tester) async {
    final items = [
      StoryItem(
        const SizedBox.expand(),
        duration: const Duration(seconds: 5),
        shown: true,
      ),
    ];
    openOnLast(items);
    expect(items.single.shown, isFalse);
  });
}

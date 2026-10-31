import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_view/story_view.dart';

const _second = Duration(seconds: 1);

Future<List<int>> _pumpStories(
  WidgetTester tester,
  StoryController controller,
  List<StoryItem> items,
) async {
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
  return shown;
}

void main() {
  testWidgets('a tap on a StoryTapTarget is not a tap on the story', (
    tester,
  ) async {
    final controller = StoryController();
    var retries = 0;
    final shown = await _pumpStories(tester, controller, [
      StoryItem(
        Center(
          child: StoryTapTarget(
            onTap: () => retries++,
            child: const SizedBox(key: Key('retry'), width: 120, height: 40),
          ),
        ),
        duration: _second * 5,
      ),
      StoryItem(const SizedBox.expand(), duration: _second * 5),
    ]);

    await tester.tap(find.byKey(const Key('retry')));
    await tester.pump(_second);
    expect(retries, 1);
    expect(shown, [0]);

    // Anywhere else still moves on.
    await tester.tapAt(const Offset(700, 300));
    await tester.pump(_second);
    expect(shown, [0, 1]);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('rewind gives the story its whole time again', (tester) async {
    final controller = StoryController();
    final shown = await _pumpStories(tester, controller, [
      StoryItem(const SizedBox.expand(), duration: _second * 2),
      StoryItem(const SizedBox.expand(), duration: _second * 2),
    ]);

    await tester.pump(const Duration(milliseconds: 1500));
    controller.rewind();
    await tester.pump();
    await tester.pump(_second);
    // Without the rewind this one would have ended by now.
    expect(shown, [0]);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(shown, [0, 1]);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

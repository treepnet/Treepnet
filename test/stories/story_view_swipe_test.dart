import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_view/story_view.dart';

const _ms = Duration(milliseconds: 1);

Future<List<Direction?>> _pumpStory(
  WidgetTester tester,
  StoryController controller,
) async {
  final swipes = <Direction?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: StoryView(
        storyItems: [
          StoryItem(
            const SizedBox.expand(),
            duration: const Duration(seconds: 10),
          ),
        ],
        controller: controller,
        onVerticalSwipeComplete: swipes.add,
      ),
    ),
  );
  return swipes;
}

void main() {
  testWidgets('a flick that ends before any drag update still swipes', (
    tester,
  ) async {
    final controller = StoryController();
    final swipes = await _pumpStory(tester, controller);

    // Small moves under the touch slop, then one that crosses it and the
    // finger lifts: the drag starts and ends with no update in between.
    final gesture = await tester.startGesture(const Offset(600, 300));
    await gesture.moveBy(const Offset(0, 5), timeStamp: _ms * 10);
    await gesture.moveBy(const Offset(0, 5), timeStamp: _ms * 20);
    await gesture.moveBy(const Offset(0, 5), timeStamp: _ms * 30);
    await gesture.moveBy(const Offset(0, 15), timeStamp: _ms * 40);
    await gesture.up(timeStamp: _ms * 45);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(swipes, [Direction.down]);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('a drag that starts and stops without speed is no swipe', (
    tester,
  ) async {
    final controller = StoryController();
    final swipes = await _pumpStory(tester, controller);

    final gesture = await tester.startGesture(const Offset(600, 300));
    await gesture.moveBy(const Offset(0, 30), timeStamp: _ms * 500);
    await gesture.up(timeStamp: _ms * 1000);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(swipes, isEmpty);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('a full drag up swipes up', (tester) async {
    final controller = StoryController();
    final swipes = await _pumpStory(tester, controller);

    await tester.dragFrom(const Offset(600, 400), const Offset(0, -200));
    await tester.pump();

    expect(swipes, [Direction.up]);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/feed/post/video/widgets/video_player_inherited_widget.dart';
import 'package:treepnet/feed/widgets/feed_tabs.dart';

/// A tab with state of its own: a counter.
class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('count $count'),
  );
}

Widget _pager(PageController controller, {required bool keepAlive}) {
  Widget tab(Widget child) =>
      keepAlive ? FeedKeepAliveTab(child: child) : child;
  return MaterialApp(
    home: PageView(
      controller: controller,
      children: [tab(const _Counter()), tab(const Text('stories'))],
    ),
  );
}

Future<void> _toStoriesAndBack(
  WidgetTester tester,
  PageController controller,
) async {
  controller.jumpToPage(1);
  await tester.pumpAndSettle();
  expect(find.text('stories'), findsOneWidget);
  controller.jumpToPage(0);
  await tester.pumpAndSettle();
}

void main() {
  group('FeedKeepAliveTab', () {
    testWidgets('keeps the Posts tab as it was after a trip to Stories', (
      tester,
    ) async {
      final controller = PageController();
      await tester.pumpWidget(_pager(controller, keepAlive: true));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      await tester.tap(find.text('count 1'));
      await tester.pump();
      await _toStoriesAndBack(tester, controller);
      expect(find.text('count 2'), findsOneWidget);
    });

    testWidgets('without it the tab is rebuilt from scratch (the old bug)', (
      tester,
    ) async {
      final controller = PageController();
      await tester.pumpWidget(_pager(controller, keepAlive: false));
      await tester.tap(find.text('count 0'));
      await tester.pump();
      await _toStoriesAndBack(tester, controller);
      expect(find.text('count 0'), findsOneWidget);
    });
  });

  group('FeedTabsVideoGate', () {
    test('feed videos stop on Stories and play again on Posts', () {
      final state = VideoPlayerState();
      final gate = FeedTabsVideoGate(state)..tabChanged(1);
      expect(state.shouldPlayFeed.value, isFalse);
      gate.tabChanged(0);
      expect(state.shouldPlayFeed.value, isTrue);
      gate.dispose();
    });

    test('turning feed playback on while Stories is shown is undone', () {
      final state = VideoPlayerState();
      final gate = FeedTabsVideoGate(state)..tabChanged(1);
      state.playFeed(); // e.g. the bottom bar, back on the feed's branch
      expect(state.shouldPlayFeed.value, isFalse);
      gate.dispose();
    });

    test(
      'on Posts it leaves playback alone, and stops watching on dispose',
      () {
        final state = VideoPlayerState();
        final gate = FeedTabsVideoGate(state);
        state
          ..stopAll()
          ..playFeed();
        expect(state.shouldPlayFeed.value, isTrue);
        gate
          ..tabChanged(1)
          ..dispose();
        state.playFeed();
        expect(state.shouldPlayFeed.value, isTrue);
      },
    );
  });
}

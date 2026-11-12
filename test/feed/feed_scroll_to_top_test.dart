import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/feed/widgets/feed_page_controller.dart';

/// Two scrollable tabs side by side, like the feed's Posts and Stories.
Widget _tabs(ScrollController posts, ScrollController stories) => MaterialApp(
  home: Row(
    children: [
      for (final controller in [posts, stories])
        Expanded(
          child: ListView.builder(
            controller: controller,
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 80, child: Text('$i')),
          ),
        ),
    ],
  ),
);

void main() {
  late ScrollController posts;
  late ScrollController stories;
  late int tab;
  late List<int> shownTabs;

  Future<void> setUpFeed(WidgetTester tester) async {
    posts = ScrollController();
    stories = ScrollController();
    tab = 0;
    shownTabs = [];
    await tester.pumpWidget(_tabs(posts, stories));
    FeedPageController()
      ..init(
        nestedScrollController: posts,
        context: tester.element(find.byType(Row)),
        currentTab: () => tab,
        showTab: (t) {
          shownTabs.add(t);
          tab = t;
        },
      )
      ..attachStoriesScroll(stories);
    posts.jumpTo(2000);
    stories.jumpTo(1500);
    await tester.pump();
  }

  tearDown(() {
    FeedPageController()
      ..detach(posts)
      ..detachStoriesScroll(stories);
  });

  testWidgets('tapping Feed again on Posts scrolls the posts up', (
    tester,
  ) async {
    await setUpFeed(tester);
    FeedPageController().scrollToTop();
    await tester.pumpAndSettle();
    expect(posts.offset, 0);
    expect(stories.offset, 1500);
  });

  testWidgets('on Stories it scrolls the Stories grid up instead', (
    tester,
  ) async {
    await setUpFeed(tester);
    tab = 1;
    FeedPageController().scrollToTop();
    await tester.pumpAndSettle();
    expect(stories.offset, 0);
    expect(posts.offset, 2000);
  });

  testWidgets('after sharing a post: Posts tab, at the top', (tester) async {
    await setUpFeed(tester);
    tab = 1;
    FeedPageController().showNewPost();
    await tester.pumpAndSettle();
    expect(shownTabs, [0]);
    expect(posts.offset, 0);
  });

  testWidgets('with the feed gone it does nothing (no assert)', (tester) async {
    await setUpFeed(tester);
    FeedPageController().detach(posts);
    FeedPageController().scrollToTop();
    FeedPageController().showNewPost();
    await tester.pumpAndSettle();
    expect(posts.offset, 2000);
    expect(shownTabs, isEmpty);
  });
}

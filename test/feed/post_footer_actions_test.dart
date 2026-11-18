import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The footer is the card's own part; the new feed turns its buttons off.
// ignore: implementation_imports
import 'package:instagram_blocks_ui/src/like_button.dart';
// ignore: implementation_imports
import 'package:instagram_blocks_ui/src/post_large/post_footer.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' show TimeAgo;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared/shared.dart';

/// The new feed (a prototype) keeps the post's buttons on its globe's small
/// card: under the post, its place instead, and its description as ever.
void main() {
  // The time under the description.
  setUpAll(initializeDateFormatting);

  final post = PostLargeBlock(
    id: 'post-1',
    author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
    createdAt: DateTime(2026),
    media: const [ImageMedia(id: 'm1', url: '')],
    caption: 'Samarkand at dawn',
  );

  Future<void> pump(
    WidgetTester tester, {
    Widget? place,
    bool showCaption = true,
    bool showTime = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PostFooter(
          block: post,
          indicatorValue: ValueNotifier(0),
          mediasUrl: const [],
          isLiked: false,
          likePost: () {},
          isBookmarked: false,
          bookmarkPost: () {},
          commentsCount: 0,
          onAvatarTap: (_) {},
          onUserTap: (_) {},
          onCommentsTap: (_) {},
          onPostShareTap: (_, _) {},
          inPlaceOfActions: place,
          showCaption: showCaption,
          showTime: showTime,
        ),
      ),
    ),
  );

  testWidgets('the usual feed: the buttons, then the description', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(LikeButton), findsOneWidget);
    expect(find.text('Samarkand at dawn'), findsOneWidget);
  });

  testWidgets('the new feed: its place where the buttons were, then the '
      'description', (tester) async {
    await pump(tester, place: const Text('Registan'));
    expect(find.byType(LikeButton), findsNothing);
    final place = tester.getRect(find.text('Registan'));
    final description = tester.getRect(find.text('Samarkand at dawn'));
    expect(place.bottom, lessThan(description.top));
  });

  testWidgets("Trends' Maps tab: no description, its time still there", (
    tester,
  ) async {
    await pump(tester, place: const Text('arrows'), showCaption: false);
    expect(find.text('Samarkand at dawn'), findsNothing);
    expect(find.byType(TimeAgo), findsOneWidget);
    expect(find.text('arrows'), findsOneWidget);
  });

  testWidgets('its time not under it when it went up beside the arrows', (
    tester,
  ) async {
    await pump(
      tester,
      place: const Text('arrows'),
      showCaption: false,
      showTime: false,
    );
    expect(find.byType(TimeAgo), findsNothing);
  });
}

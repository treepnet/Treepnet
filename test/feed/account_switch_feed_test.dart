import 'package:flutter_test/flutter_test.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockPostsRepository extends Mock implements PostsRepository {}

Post _post(String id) => Post(
  id: id,
  createdAt: DateTime(2026),
  author: const User(id: 'a'),
  caption: '',
);

List<String> _ids(List<InstaBlock> blocks) => [
  for (final block in blocks)
    if (block is PostBlock) block.id,
];

void main() {
  late _MockPostsRepository posts;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  void answer(List<Post> page) => when(
    () => posts.getPage(
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      order: any(named: 'order'),
    ),
  ).thenAnswer((_) async => page);

  setUpAll(() => registerFallbackValue(PostOrder.feed));
  setUp(() {
    posts = _MockPostsRepository();
    when(() => posts.postRemovals).thenAnswer((_) => const Stream.empty());
  });

  test('a feed read to its end still reloads its first page', () async {
    final bloc = FeedBloc(postsRepository: posts);
    // The last account's feed, short enough to have no more pages.
    answer([_post('a1')]);
    bloc.add(const FeedRefreshRequested());
    await settle();
    expect(bloc.state.feed.feedPage.hasMore, isFalse);

    // The next feed opens: page 0 is fetched again, not skipped.
    answer([_post('b1'), _post('b2')]);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const FeedPageRequested(page: 0));
    await settle();
    expect(_ids(bloc.state.feed.feedPage.blocks), ['b1', 'b2']);
    await bloc.close();
  });

  test("another account signing in starts from an empty feed", () async {
    final bloc = FeedBloc(postsRepository: posts);
    answer([_post('a1')]);
    bloc.add(const FeedRefreshRequested());
    await settle();
    expect(_ids(bloc.state.feed.feedPage.blocks), ['a1']);

    bloc.add(const FeedResetRequested());
    await settle();
    expect(bloc.state, const FeedState.initial());
    await bloc.close();
  });
}

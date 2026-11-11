import 'package:flutter_test/flutter_test.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/timeline/timeline.dart';
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

/// A page the server couldn't send is not the end of the list: the posts the
/// phone had are shown and the same page is asked for again.
void main() {
  late _MockPostsRepository posts;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  void answer(List<Post> Function() page) => when(
    () => posts.getPage(
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      order: any(named: 'order'),
    ),
  ).thenAnswer((_) async => page());

  void fail(List<Post> local) => when(
    () => posts.getPage(
      offset: any(named: 'offset'),
      limit: any(named: 'limit'),
      order: any(named: 'order'),
    ),
  ).thenThrow(PostsPageIncomplete(local, Exception('offline')));

  setUpAll(() => registerFallbackValue(PostOrder.feed));
  setUp(() => posts = _MockPostsRepository());

  test(
    'the feed keeps its page and shows the phone\'s posts, then retries',
    () async {
      final bloc = FeedBloc(postsRepository: posts);
      fail([_post('mine')]);
      bloc.add(const FeedPageRequested());
      await settle();

      expect(bloc.state.status, FeedStatus.failure);
      expect(_ids(bloc.state.feed.feedPage.blocks), ['mine']);
      expect(bloc.state.feed.feedPage.page, 0);
      expect(bloc.state.feed.feedPage.hasMore, isTrue);

      // Retry: the same page, now from the server too; nothing twice.
      answer(() => [_post('mine'), _post('other')]);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      bloc.add(const FeedPageRequested());
      await settle();

      expect(bloc.state.status, FeedStatus.populated);
      expect(_ids(bloc.state.feed.feedPage.blocks), ['mine', 'other']);
      expect(bloc.state.feed.feedPage.page, 1);
      await bloc.close();
    },
  );

  test('a failed refresh of an empty feed shows the phone\'s posts', () async {
    final bloc = FeedBloc(postsRepository: posts);
    fail([_post('mine')]);
    bloc.add(const FeedRefreshRequested());
    await settle();

    expect(bloc.state.status, FeedStatus.failure);
    expect(_ids(bloc.state.feed.feedPage.blocks), ['mine']);
    expect(bloc.state.feed.feedPage.page, 0);
    await bloc.close();
  });

  test('Trends keeps its page after a failed one, then retries', () async {
    final bloc = TimelineBloc(postsRepository: posts);
    answer(() => List.generate(15, (i) => _post('t$i')));
    bloc.add(const TimelinePageRequested());
    await settle();
    expect(bloc.state.timeline.page, 1);

    fail(const []);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelinePageRequested());
    await settle();
    expect(bloc.state.status, TimelineStatus.failure);
    expect(bloc.state.timeline.page, 1);
    expect(bloc.state.timeline.hasMore, isTrue);
    expect(bloc.state.timeline.blocks, hasLength(15));

    answer(() => [_post('t15')]);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelinePageRequested());
    await settle();
    expect(bloc.state.status, TimelineStatus.populated);
    expect(bloc.state.timeline.blocks, hasLength(16));
    await bloc.close();
  });
}

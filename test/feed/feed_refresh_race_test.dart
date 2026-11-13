import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockPostsRepository extends Mock implements PostsRepository {}

List<Post> _page(String prefix) => [
  for (var i = 0; i < 15; i++)
    Post(
      id: '$prefix$i',
      createdAt: DateTime(2026),
      author: const User(id: 'a'),
      caption: '',
    ),
];

List<String> _ids(List<InstaBlock> blocks) => [
  for (final block in blocks)
    if (block is PostBlock) block.id,
];

/// A refresh and the next page used to run at once: a page that landed after
/// the refresh was added to the fresh first page with its old number, and
/// the posts in between were skipped.
void main() {
  late _MockPostsRepository posts;

  /// What each getPage call answers, in order.
  late List<Future<List<Post>> Function()> answers;
  late List<int> offsets;

  Future<void> settle([int ms = 20]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUpAll(() => registerFallbackValue(PostOrder.feed));
  setUp(() {
    posts = _MockPostsRepository();
    answers = [];
    offsets = [];
    when(() => posts.postRemovals).thenAnswer((_) => const Stream.empty());
    when(
      () => posts.getPage(
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((invocation) {
      offsets.add(invocation.namedArguments[#offset] as int);
      return answers.removeAt(0)();
    });
  });

  Future<FeedBloc> populated() async {
    final bloc = FeedBloc(postsRepository: posts);
    answers.add(() async => _page('a'));
    bloc.add(const FeedPageRequested(page: 0));
    await settle(600); // past the refresh's throttle
    expect(bloc.state.feed.feedPage.page, 1);
    return bloc;
  }

  test('a page that lands after a refresh is dropped', () async {
    final bloc = await populated();
    final slowPage = Completer<List<Post>>();
    answers
      ..add(() => slowPage.future) // the next page, slow
      ..add(() async => _page('f')); // the refresh
    bloc.add(const FeedPageRequested());
    await settle();
    bloc.add(const FeedRefreshRequested());
    await settle();
    expect(
      _ids(bloc.state.feed.feedPage.blocks),
      _ids(_page('f').map((p) => p.toPostLargeBlock).toList()),
    );

    slowPage.complete(_page('b'));
    await settle();
    expect(
      _ids(bloc.state.feed.feedPage.blocks).first,
      'f0',
      reason: 'the fresh first page',
    );
    expect(
      _ids(bloc.state.feed.feedPage.blocks).any((id) => id.startsWith('b')),
      isFalse,
      reason: 'the old page 1 is not glued on',
    );
    expect(bloc.state.feed.feedPage.page, 1, reason: 'paging goes on from 1');
    await bloc.close();
  });

  test('no next page is asked for while a refresh runs', () async {
    final bloc = await populated();
    final slowRefresh = Completer<List<Post>>();
    answers.add(() => slowRefresh.future);
    bloc.add(const FeedRefreshRequested());
    await settle();
    bloc.add(const FeedPageRequested());
    await settle();
    expect(offsets, [0, 0], reason: 'only the two first-page fetches');

    slowRefresh.complete(_page('f'));
    await settle(600);
    answers.add(() async => _page('g'));
    bloc.add(const FeedPageRequested());
    await settle();
    expect(offsets.last, 15, reason: 'after it, page 1 as usual');
    expect(_ids(bloc.state.feed.feedPage.blocks).last, 'g14');
    await bloc.close();
  });
}

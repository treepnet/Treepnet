import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/timeline/timeline.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockPostsRepository extends Mock implements PostsRepository {}

Post _post(String id) => Post(
  id: id,
  createdAt: DateTime(2026),
  author: User(id: 'author-$id'),
  caption: '',
);

List<Post> _posts(String prefix, int count) => [
  for (var i = 0; i < count; i++) _post('$prefix$i'),
];

List<String> _ids(TimelineState state) => [
  for (final block in state.timeline.blocks)
    if (block is PostBlock) block.id,
];

/// Trends' pages and its refresh (both tabs, the grid and Maps): a page
/// asked for before a refresh landed after it, on the fresh first page —
/// the posts in between skipped.
void main() {
  late _MockPostsRepository posts;

  /// The answers to come, by offset.
  late Map<int, Completer<List<Post>>> pages;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUpAll(() => registerFallbackValue(PostOrder.trending));
  setUp(() {
    posts = _MockPostsRepository();
    pages = {};
    when(() => posts.postRemovals).thenAnswer((_) => const Stream.empty());
    when(
      () => posts.getPage(
        offset: any(named: 'offset'),
        limit: any(named: 'limit'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (call) =>
          (pages[call.namedArguments[#offset] as int] ??= Completer()).future,
    );
  });

  Future<TimelineBloc> withFirstPage() async {
    final bloc = TimelineBloc(postsRepository: posts)
      ..add(const TimelinePageRequested());
    await settle();
    pages.remove(0)!.complete(_posts('first', 24));
    await settle();
    expect(bloc.state.timeline.page, 1);
    return bloc;
  }

  test('a page that lands after a refresh began is dropped', () async {
    final bloc = await withFirstPage();
    // Past the pages' throttle.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelinePageRequested());
    await settle();
    final page = pages.remove(24)!;
    final refreshes = bloc.refreshes;
    // Wait out the refresh's throttle, then refresh.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelineRefreshRequested());
    await settle();
    // Whoever waits for the page sees it dropped (the grid's spinner).
    expect(bloc.refreshes, isNot(refreshes));
    pages.remove(0)!.complete(_posts('fresh', 24));
    await settle();
    page.complete(_posts('old', 24));
    await settle();
    expect(_ids(bloc.state), [for (var i = 0; i < 24; i++) 'fresh$i']);
    expect(bloc.state.timeline.page, 1, reason: 'the next page is page 1');
    await bloc.close();
  });

  test('no next page is asked for while a refresh runs', () async {
    final bloc = await withFirstPage();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelineRefreshRequested());
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelinePageRequested());
    await settle();
    expect(pages.containsKey(24), isFalse);
    pages.remove(0)!.complete(_posts('fresh', 24));
    await settle();
    expect(bloc.state.status, TimelineStatus.populated);
    await bloc.close();
  });

  test('which failed last, a refresh or a page, is what comes back', () async {
    final bloc = await withFirstPage();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelineRefreshRequested());
    await settle();
    pages.remove(0)!.completeError(Exception('offline'));
    await settle();
    expect(bloc.state.status, TimelineStatus.failure);
    expect(bloc.refreshFailed, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 600));
    bloc.add(const TimelinePageRequested());
    await settle();
    pages.remove(24)!.completeError(Exception('offline'));
    await settle();
    expect(bloc.state.status, TimelineStatus.failure);
    expect(bloc.refreshFailed, isFalse);
    await bloc.close();
  });
}

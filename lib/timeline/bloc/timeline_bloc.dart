import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';

part 'timeline_event.dart';
part 'timeline_state.dart';

class TimelineBloc extends Bloc<TimelineEvent, TimelineState> {
  TimelineBloc({required PostsRepository postsRepository})
    : _postsRepository = postsRepository,
      super(const TimelineState.initial()) {
    on<TimelinePageRequested>(
      _onTimelinePageRequested,
      transformer: throttleDroppable(),
    );
    on<TimelineRefreshRequested>(
      _onTimelineRefreshRequested,
      transformer: throttleDroppable(duration: 550.ms),
    );
    on<TimelinePostsRemoved>(_onPostsRemoved);
    _removals = postsRepository.postRemovals.listen(
      (removal) => add(TimelinePostsRemoved(removal)),
    );
  }

  final PostsRepository _postsRepository;
  late final StreamSubscription<PostRemoval> _removals;

  /// The posts behind the tiles, by id: a tap opens them in a list at once,
  /// without asking the server for them again.
  final Map<String, Post> _posts = {};

  /// The grid's posts in its order — the list a tapped tile opens on.
  List<Post> postsFor(List<PostBlock> blocks) => [
    for (final block in blocks)
      if (_posts[block.id] case final post?) post,
  ];

  /// Trends from [offset], [limit] at a time: where that list goes on.
  Future<List<Post>> morePosts(int offset, int limit) => _postsRepository
      .getPage(offset: offset, limit: limit, order: PostOrder.trending);

  void _keep(Iterable<Post> posts) {
    for (final post in posts) {
      _posts[post.id] = post;
    }
  }

  @override
  Future<void> close() async {
    await _removals.cancel();
    return super.close();
  }

  /// A deleted, hidden or archived post, or a blocked author's posts, leave
  /// the grid at once. A stale tile used to stay, and tapping it opened a
  /// different post (the gone one has no place in the order any more).
  void _onPostsRemoved(
    TimelinePostsRemoved event,
    Emitter<TimelineState> emit,
  ) {
    final blocks = state.timeline.blocks;
    final kept = [
      for (final block in blocks)
        if (block is! PostBlock ||
            !event.removal.removes(postId: block.id, authorId: block.author.id))
          block,
    ];
    if (kept.length == blocks.length) return;
    emit(
      state.copyWith(
        timeline: state.timeline.copyWith(
          blocks: kept,
          totalBlocks: kept.length,
        ),
      ),
    );
  }

  /// Trends posts per page: 24, eight full rows of the 3-column grid (it
  /// was 15). feed_page_ids takes up to 100.
  static const _pageSize = 24;

  /// Bumped by every refresh, as the feed's (FeedBloc): a next page asked
  /// for before a refresh landed after it, on the fresh first page with its
  /// old number — the posts in between skipped (both tabs; the Maps tab's
  /// end asked for one as a refresh began). A page that lands after a
  /// refresh began is dropped, and none is asked for while one runs.
  int _generation = 0;
  bool _refreshing = false;

  /// How many refreshes have begun: one that begins while a page is on its
  /// way drops that page (above), so whoever waits for the page stops
  /// waiting when this changes.
  int get refreshes => _generation;

  /// Whether the last request that failed was a refresh (a pull to refresh)
  /// rather than a later page: once back online, that is what is asked for
  /// again — a refresh, or that page.
  bool get refreshFailed => _refreshFailed;
  bool _refreshFailed = false;

  Future<void> _onTimelinePageRequested(
    TimelinePageRequested event,
    Emitter<TimelineState> emit,
  ) async {
    // Loading only while there is nothing on screen yet (the first page) or
    // on a Retry after a failed page; a later page keeps the grid as it is.
    // This used to say "populated" here, so an empty first page looked
    // finished at once.
    if (_refreshing) return;
    final generation = _generation;
    if (state.timeline.blocks.isEmpty || state.status.isFailure) {
      emit(state.copyWith(status: TimelineStatus.loading));
    }
    try {
      final currentPage = event.page ?? state.timeline.page;

      final posts = await _postsRepository.getPage(
        limit: _pageSize,
        offset: _pageSize * currentPage,
        order: PostOrder.trending,
      );
      if (generation != _generation) return;

      final newPage = currentPage + 1;

      final hasMore = posts.length >= _pageSize;
      _keep(posts);

      final blocks = <InstaBlock>[];
      for (final post in posts) {
        final block = post.toPostSmallBlock;
        blocks.add(block);
      }

      // Without the posts already shown: offset pages shift when one is
      // added or synced meanwhile.
      final updatedBlocks = state.timeline.blocks.appendNew(blocks);
      final timeline = state.timeline.copyWith(
        page: newPage,
        hasMore: hasMore,
        blocks: updatedBlocks,
        totalBlocks: updatedBlocks.length,
      );

      _refreshFailed = false;
      emit(
        state.copyWith(status: TimelineStatus.populated, timeline: timeline),
      );
    } on PostsPageIncomplete catch (incomplete, stackTrace) {
      if (generation != _generation) return;
      _refreshFailed = false;
      // Not the end of Trends: what the phone had goes on screen and the grid
      // ends in a Retry for the same page.
      _keep(incomplete.posts);
      final updatedBlocks = state.timeline.blocks.appendNew([
        for (final post in incomplete.posts) post.toPostSmallBlock,
      ]);
      emit(
        state.copyWith(
          status: TimelineStatus.failure,
          timeline: state.timeline.copyWith(
            blocks: updatedBlocks,
            totalBlocks: updatedBlocks.length,
          ),
        ),
      );
      addError(incomplete.cause, stackTrace);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (generation != _generation) return;
      _refreshFailed = false;
      emit(state.copyWith(status: TimelineStatus.failure));
    }
  }

  Future<void> _onTimelineRefreshRequested(
    TimelineRefreshRequested event,
    Emitter<TimelineState> emit,
  ) async {
    final generation = ++_generation;
    _refreshing = true;
    emit(state.copyWith(status: TimelineStatus.loading));
    try {
      const currentPage = 0;

      final posts = await _postsRepository.getPage(
        limit: _pageSize,
        offset: _pageSize * currentPage,
        order: PostOrder.trending,
      );
      if (generation != _generation) return; // a newer refresh is on its way

      const newPage = currentPage + 1;

      final hasMore = posts.length >= _pageSize;
      _posts.clear();
      _keep(posts);

      final blocks = <InstaBlock>[];
      for (final post in posts) {
        final block = post.toPostSmallBlock;
        blocks.add(block);
      }

      final timeline = FeedPage(
        page: newPage,
        hasMore: hasMore,
        blocks: blocks,
        totalBlocks: blocks.length,
      );

      _refreshFailed = false;
      emit(
        state.copyWith(status: TimelineStatus.populated, timeline: timeline),
      );
    } on PostsPageIncomplete catch (incomplete, stackTrace) {
      if (generation != _generation) return;
      _refreshFailed = true;
      // Posts already on screen stay; an empty grid shows what the phone had,
      // from page 0, so Retry asks for the first page again.
      _keep(incomplete.posts);
      final blocks = [
        for (final post in incomplete.posts) post.toPostSmallBlock,
      ];
      emit(
        state.timeline.blocks.isNotEmpty || blocks.isEmpty
            ? state.copyWith(status: TimelineStatus.failure)
            : state.copyWith(
                status: TimelineStatus.failure,
                timeline: FeedPage(
                  page: 0,
                  hasMore: true,
                  blocks: blocks,
                  totalBlocks: blocks.length,
                ),
              ),
      );
      addError(incomplete.cause, stackTrace);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (generation != _generation) return;
      _refreshFailed = true;
      emit(state.copyWith(status: TimelineStatus.failure));
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }
}

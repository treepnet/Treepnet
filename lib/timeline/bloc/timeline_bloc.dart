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
  }

  final PostsRepository _postsRepository;

  static const _pageSize = 15;

  Future<void> _onTimelinePageRequested(
    TimelinePageRequested event,
    Emitter<TimelineState> emit,
  ) async {
    // Loading only while there is nothing on screen yet (the first page or a
    // retry); a later page keeps the grid as it is. This used to say
    // "populated" here, so an empty first page looked finished at once.
    if (state.timeline.blocks.isEmpty) {
      emit(state.copyWith(status: TimelineStatus.loading));
    }
    try {
      final currentPage = event.page ?? state.timeline.page;

      final posts = await _postsRepository.getPage(
        limit: _pageSize,
        offset: _pageSize * currentPage,
        order: PostOrder.trending,
      );

      final newPage = currentPage + 1;

      final hasMore = posts.length >= _pageSize;

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

      emit(
        state.copyWith(status: TimelineStatus.populated, timeline: timeline),
      );
    } catch (error, stackTrace) {
      emit(state.copyWith(status: TimelineStatus.failure));
      addError(error, stackTrace);
    }
  }

  Future<void> _onTimelineRefreshRequested(
    TimelineRefreshRequested event,
    Emitter<TimelineState> emit,
  ) async {
    emit(state.copyWith(status: TimelineStatus.loading));
    try {
      const currentPage = 0;

      final posts = await _postsRepository.getPage(
        limit: _pageSize,
        offset: _pageSize * currentPage,
        order: PostOrder.trending,
      );

      const newPage = currentPage + 1;

      final hasMore = posts.length >= _pageSize;

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

      emit(
        state.copyWith(status: TimelineStatus.populated, timeline: timeline),
      );
    } catch (error, stackTrace) {
      emit(state.copyWith(status: TimelineStatus.failure));
      addError(error, stackTrace);
    }
  }
}

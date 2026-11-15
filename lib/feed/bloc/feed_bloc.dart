import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';

part 'feed_bloc_mixin.dart';
part 'feed_event.dart';
part 'feed_state.dart';

class FeedBloc extends Bloc<FeedEvent, FeedState> with FeedBlocMixin {
  FeedBloc({
    required PostsRepository postsRepository,
  }) : _postsRepository = postsRepository,
       super(const FeedState.initial()) {
    // Droppable: an empty feed keeps its loader on screen, and the loader asks
    // for the next page every time it is presented. Without this a brand-new
    // account span in a permanent refresh loop.
    on<FeedPageRequested>(
      _onFeedPageRequested,
      transformer: throttleDroppable(duration: 550.ms),
    );
    on<FeedRefreshRequested>(
      _onFeedRefreshRequested,
      transformer: throttleDroppable(duration: 550.ms),
    );
    on<FeedUpdateRequested>(_onFeedUpdateRequested);
    on<FeedResetRequested>(
      (event, emit) => emit(const FeedState.initial()),
    );
  }

  @override
  PostsRepository get postsRepository => _postsRepository;

  final PostsRepository _postsRepository;

  /// Bumped by every refresh. A refresh and a next page ran at once: a page
  /// asked for before the refresh landed after it and was added to the fresh
  /// first page with its old number (posts 1-7, then page N: everything in
  /// between skipped until the next refresh). A page that lands after a
  /// refresh began is dropped, and none is asked for while one runs (the
  /// loader asks again once the list is back).
  int _generation = 0;
  bool _refreshing = false;

  Future<void> _onFeedPageRequested(
    FeedPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    // The first page is always fetched afresh. This came after the "no more
    // pages" check, so a feed read to its end (by the last account, too)
    // never reloaded until a manual refresh.
    if (event.page == 0) return add(const FeedRefreshRequested());
    if (_refreshing) return;
    // The end of the feed. (It used to ask for "recommended posts" here, a
    // template leftover that was always an empty list.)
    if (!state.feed.feedPage.hasMore) return;
    final generation = _generation;
    emit(state.loading());
    try {
      final currentPage = event.page ?? state.feed.feedPage.page;
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage(
        page: currentPage,
      );
      if (generation != _generation) return;

      // Without the posts already shown: offset pages shift when one is
      // added or synced meanwhile.
      final updatedBlocks = state.feed.feedPage.blocks.appendNew(blocks);
      final feed = state.feed.copyWith(
        feedPage: state.feed.feedPage.copyWith(
          page: newPage,
          hasMore: hasMore,
          blocks: updatedBlocks,
          totalBlocks: updatedBlocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } on FeedPageIncomplete catch (incomplete, stackTrace) {
      // Not the end of the feed: what the phone had goes on screen, and the
      // list ends in a Retry for the same page.
      addError(incomplete.cause, stackTrace);
      if (generation != _generation) return;
      final updatedBlocks = state.feed.feedPage.blocks.appendNew(
        incomplete.blocks,
      );
      emit(
        state
            .copyWith(
              feed: state.feed.copyWith(
                feedPage: state.feed.feedPage.copyWith(
                  blocks: updatedBlocks,
                  totalBlocks: updatedBlocks.length,
                ),
              ),
            )
            .failure(),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (generation != _generation) return;
      emit(state.failure());
    }
  }

  Future<void> _onFeedRefreshRequested(
    FeedRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    final generation = ++_generation;
    _refreshing = true;
    emit(state.loading());
    try {
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage();
      if (generation != _generation) return; // a newer refresh is on its way
      final feed = state.feed.copyWith(
        feedPage: FeedPage(
          page: newPage,
          blocks: blocks,
          hasMore: hasMore,
          totalBlocks: blocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } on FeedPageIncomplete catch (incomplete, stackTrace) {
      addError(incomplete.cause, stackTrace);
      if (generation != _generation) return;
      // Posts already on screen stay; an empty feed shows what the phone had,
      // from page 0, so Retry asks for the first page again.
      if (state.feed.feedPage.blocks.isNotEmpty || incomplete.blocks.isEmpty) {
        return emit(state.failure());
      }
      emit(
        state
            .copyWith(
              feed: state.feed.copyWith(
                feedPage: FeedPage(
                  page: 0,
                  blocks: incomplete.blocks,
                  hasMore: true,
                  totalBlocks: incomplete.blocks.length,
                ),
              ),
            )
            .failure(),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (generation != _generation) return;
      emit(state.failure());
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Future<void> _onFeedUpdateRequested(
    FeedUpdateRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.loading());
    final update = event.update;
    final oldFeed = state.feed;

    try {
      final feedBlock = oldFeed.feedPage.blocks.findPostBlock(
        test: (block) => block.id == update.newPost.id,
      );
      if (feedBlock == null && !update.isCreate) {
        return emit(state.populated());
      }
      final updatedFeedBlocks = oldFeed.updateFeedPage(update: update);

      final feed = oldFeed.copyWith(
        feedPage: oldFeed.feedPage.copyWith(
          blocks: updatedFeedBlocks,
          totalBlocks: updatedFeedBlocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
    }
  }
}

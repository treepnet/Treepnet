import 'dart:async';
import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:treepnet/app/app.dart';
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
    on<FeedReelsPageRequested>(
      _onFeedReelsPageRequested,
      transformer: sequential(),
    );
    on<FeedRefreshRequested>(
      _onFeedRefreshRequested,
      transformer: throttleDroppable(duration: 550.ms),
    );
    on<FeedReelsRefreshRequested>(
      _onFeedReelsRefreshRequested,
      transformer: throttleDroppable(duration: 550.ms),
    );
    on<FeedRecommendedPostsPageRequested>(
      _onFeedRecommendedPostsPageRequested,
      transformer: sequential(),
    );
    on<FeedPostCreateRequested>(_onFeedPostCreateRequested);
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
  /// between skipped until the next refresh). A page or recommended posts
  /// that land after a refresh began are dropped, and none is asked for while
  /// one runs (the loader asks again once the list is back).
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
    if (!state.feed.feedPage.hasMore) {
      return add(const FeedRecommendedPostsPageRequested());
    }
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

  Future<void> _onFeedReelsPageRequested(
    FeedReelsPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.loading());
    try {
      final currentPage = event.page ?? state.feed.reelsPage.page;
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage(
        page: currentPage,
        mapper: postsToReelBlockMapper,
      );

      final updatedReels = state.feed.reelsPage.blocks.appendNew(blocks);
      final feed = state.feed.copyWith(
        reelsPage: state.feed.reelsPage.copyWith(
          page: newPage,
          hasMore: hasMore,
          blocks: updatedReels,
          totalBlocks: updatedReels.length,
        ),
      );
      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
    }
  }

  Future<void> _onFeedReelsRefreshRequested(
    FeedReelsRefreshRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.loading());
    try {
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage(
        mapper: postsToReelBlockMapper,
      );

      final feed = state.feed.copyWith(
        reelsPage: ReelsPage(
          page: newPage,
          hasMore: hasMore,
          blocks: blocks,
          totalBlocks: blocks.length,
        ),
      );
      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
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

  Future<void> _onFeedRecommendedPostsPageRequested(
    FeedRecommendedPostsPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (_refreshing) return;
    final generation = _generation;
    emit(state.loading());
    try {
      final recommendedBlocks = await compute(
        _shuffleRecommendedPosts,
        PostsRepository.recommendedPosts.withNavigateToPostAuthorAction,
      );
      if (generation != _generation) return;

      final updatedBlocks = state.feed.feedPage.blocks.appendNew(
        recommendedBlocks,
      );
      final feed = state.feed.copyWith(
        feedPage: state.feed.feedPage.copyWith(
          blocks: updatedBlocks,
          totalBlocks: updatedBlocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
    }
  }

  static List<InstaBlock> _shuffleRecommendedPosts(List<InstaBlock> blocks) {
    return [...blocks..shuffle()];
  }

  Future<void> _onFeedPostCreateRequested(
    FeedPostCreateRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.loading());
    try {
      final newPost = await _postsRepository.createPost(
        id: event.postId,
        caption: event.caption,
        media: json.encode(event.media),
        location: event.location,
        locationCountry: event.locationCountry,
        locationRegion: event.locationRegion,
        locationName: event.locationName,
        locationLat: event.locationLat,
        locationLng: event.locationLng,
      );
      if (newPost != null) {
        add(
          FeedUpdateRequested(
            update: FeedPageUpdate(
              newPost: newPost,
              type: PageUpdateType.create,
            ),
          ),
        );
      }
      emit(state.populated());
      toggleLoadingIndeterminate(enable: false);
      openSnackbar(
        SnackbarMessage.success(title: l10nGlobal.successfullyCreatedPostText),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
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
      final reel = oldFeed.reelsPage.blocks.findPostBlock(
        test: (block) =>
            block.id == update.newPost.id &&
            block.type == PostReelBlock.identifier,
      );
      if (feedBlock == null && reel == null && !update.isCreate) {
        return emit(state.populated());
      }
      final updatedFeedBlocks = oldFeed.updateFeedPage(update: update);
      List<InstaBlock>? updatedReelsBlocks;
      if (update.canUpdateReel) {
        updatedReelsBlocks = oldFeed.updateReelsPage(update: update);
      }

      final feed = oldFeed.copyWith(
        feedPage: oldFeed.feedPage.copyWith(
          blocks: updatedFeedBlocks,
          totalBlocks: updatedFeedBlocks.length,
        ),
        reelsPage: oldFeed.reelsPage.copyWith(
          blocks: updatedReelsBlocks,
          totalBlocks: updatedReelsBlocks?.length,
        ),
      );

      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
    }
  }
}

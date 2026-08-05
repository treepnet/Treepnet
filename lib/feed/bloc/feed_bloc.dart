import 'dart:async';
import 'dart:convert';

import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:treepnet/app/app.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
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
  }

  @override
  PostsRepository get postsRepository => _postsRepository;

  final PostsRepository _postsRepository;

  Future<void> _onFeedPageRequested(
    FeedPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    if (!state.feed.feedPage.hasMore) {
      return add(const FeedRecommendedPostsPageRequested());
    }
    emit(state.loading());
    try {
      if (event.page != null && event.page == 0) {
        return add(const FeedRefreshRequested());
      }
      final currentPage = event.page ?? state.feed.feedPage.page;
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage(
        page: currentPage,
      );

      final feed = state.feed.copyWith(
        feedPage: state.feed.feedPage.copyWith(
          page: newPage,
          hasMore: hasMore,
          blocks: [...state.feed.feedPage.blocks, ...blocks],
          totalBlocks: state.feed.feedPage.totalBlocks + blocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      unawaited(
        Posthog().capture(
          eventName: 'FeedPageRequestedError',
          properties: {
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        ),
      );
      addError(error, stackTrace);
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

      final feed = state.feed.copyWith(
        reelsPage: state.feed.reelsPage.copyWith(
          page: newPage,
          hasMore: hasMore,
          blocks: [...state.feed.reelsPage.blocks, ...blocks],
          totalBlocks: state.feed.reelsPage.totalBlocks + blocks.length,
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
    emit(state.loading());
    try {
      final (:newPage, :hasMore, :blocks) = await fetchFeedPage();
      final feed = state.feed.copyWith(
        feedPage: FeedPage(
          page: newPage,
          blocks: blocks,
          hasMore: hasMore,
          totalBlocks: blocks.length,
        ),
      );

      emit(state.populated(feed: feed));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.failure());
    }
  }

  Future<void> _onFeedRecommendedPostsPageRequested(
    FeedRecommendedPostsPageRequested event,
    Emitter<FeedState> emit,
  ) async {
    emit(state.loading());
    try {
      final recommendedBlocks = await compute(
        _shuffleRecommendedPosts,
        PostsRepository.recommendedPosts.withNavigateToPostAuthorAction,
      );

      final feed = state.feed.copyWith(
        feedPage: state.feed.feedPage.copyWith(
          blocks: [...state.feed.feedPage.blocks, ...recommendedBlocks],
          totalBlocks: state.feed.feedPage.totalBlocks + recommendedBlocks.length,
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

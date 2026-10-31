import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:bloc/bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

part 'post_bloc.g.dart';
part 'post_event.dart';
part 'post_state.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  PostBloc({
    required String postId,
    required PostsRepository postsRepository,
    required UserRepository userRepository,
  }) : _postId = postId,
       _postsRepository = postsRepository,
       _userRepository = userRepository,
       super(const PostState.initial()) {
    on<PostStatsSubscriptionRequested>(_onPostStatsSubscriptionRequested);
    on<PostBookmarkRequested>(_onPostBookmarkRequested);
    on<PostLikersPageRequested>(_onPostLikersPageRequested);
    on<PostUpdateRequested>(_onPostUpdateRequested);
    on<PostLikeRequested>(_onPostLikeRequested);
    on<PostAuthorFollowRequested>(_onPostAuthorFollowRequested);
    on<PostDeleteRequested>(_onPostDeleteRequested);
    on<PostShareRequested>(_onPostShareRequested);
    on<PostLikersInFollowingsFetchRequested>(
      _onPostLikersInFollowingsFetchRequested,
    );
  }

  static const _usersLimit = 100;

  final UserRepository _userRepository;
  final PostsRepository _postsRepository;

  final String _postId;

  /// The post this bloc is for.
  String get id => _postId;

  Future<void> _onPostStatsSubscriptionRequested(
    PostStatsSubscriptionRequested event,
    Emitter<PostState> emit,
  ) async {
    // No follow state on your own post (no Follow button either).
    final isOwner = event.currentUserId == event.ownerId;
    if (isOwner) emit(state.copyWith(isOwner: true));
    await emit.forEach(
      _postsRepository.statsOf(postId: id),
      onData: (stats) => state.copyWith(
        likes: stats.likes,
        commentsCount: stats.comments,
        isLiked: stats.isLiked,
        isBookmarked: stats.isBookmarked,
        isOwner: isOwner,
        // Asked already counts here: the card's Follow button would otherwise
        // stay, and tapping it again withdrew the request.
        isFollowed: isOwner
            ? null
            : stats.isAuthorFollowed || stats.isAuthorFollowRequested,
        authorTier: stats.authorTier,
        authorPlaces: stats.authorPlaces,
      ),
      onError: (error, stackTrace) {
        addError(error, stackTrace);
        return state.copyWith(status: PostStatus.failure);
      },
    );
  }

  Future<void> _onPostBookmarkRequested(
    PostBookmarkRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      await _postsRepository.bookmarkPost(postId: id);
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostLikersPageRequested(
    PostLikersPageRequested event,
    Emitter<PostState> emit,
  ) async {
    final page = event.page;
    emit(state.copyWith(status: PostStatus.loading));
    try {
      final users = await _postsRepository.getPostLikers(
        postId: id,
        offset: page * _usersLimit,
        limit: _usersLimit,
      );
      emit(state.copyWith(status: PostStatus.success, likers: users));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostUpdateRequested(
    PostUpdateRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      final post = await _postsRepository.updatePost(
        id: id,
        caption: event.caption,
      );

      if (post != null) {
        event.onPostUpdated?.call(post.toPostLargeBlock);
      }
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostLikeRequested(
    PostLikeRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      await _postsRepository.like(id: id);
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      unawaited(
        Posthog().capture(
          eventName: 'PostLikedRequestedError',
          properties: {
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        ),
      );
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostAuthorFollowRequested(
    PostAuthorFollowRequested event,
    Emitter<PostState> emit,
  ) async {
    emit(state.copyWith(status: PostStatus.loading));
    try {
      await _userRepository.follow(followToId: event.authorId);
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostDeleteRequested(
    PostDeleteRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      await _postsRepository.deletePost(id: id);
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostShareRequested(
    PostShareRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      await _postsRepository.sharePost(
        id: id,
        sender: event.sender,
        receiver: event.receiver,
        sharedPostMessage: event.sharedPostMessage.copyWith(sharedPostId: id),
        message: event.message,
        postAuthor: event.postAuthor,
      );
      emit(state.copyWith(status: PostStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

  Future<void> _onPostLikersInFollowingsFetchRequested(
    PostLikersInFollowingsFetchRequested event,
    Emitter<PostState> emit,
  ) async {
    try {
      final likersInFollowings = await _postsRepository
          .getPostLikersInFollowings(postId: id);
      emit(state.copyWith(likersInFollowings: likersInFollowings));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: PostStatus.failure));
    }
  }

}

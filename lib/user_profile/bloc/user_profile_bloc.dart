import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

part 'user_profile_event.dart';
part 'user_profile_state.dart';

class UserProfileBloc extends Bloc<UserProfileEvent, UserProfileState> {
  UserProfileBloc({
    required UserRepository userRepository,
    required PostsRepository postsRepository,
    String? userId,
  }) : _userRepository = userRepository,
       _postsRepository = postsRepository,
       _userId = userId ?? userRepository.currentUserId ?? '',
       super(const UserProfileState.initial()) {
    on<UserProfileSubscriptionRequested>(
      _onUserProfileSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<UserProfilePostsCountSubscriptionRequested>(
      _onUserProfilePostsCountSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<UserProfileFollowingsCountSubscriptionRequested>(
      _onUserProfileFollowingsCountSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<UserProfileFollowersCountSubscriptionRequested>(
      _onUserProfileFollowersCountSubscriptionRequested,
      transformer: throttleDroppable(),
    );
    on<UserProfileUpdateRequested>(_onUserProfileUpdateRequested);
    on<UserProfileFetchFollowersRequested>(_onFollowersFetch);
    // restartable: growing the window re-dispatches with a bigger limit; only
    // the latest window's result should win (a stale wider/narrower fetch must
    // not overwrite it).
    on<UserProfileFetchFollowingsRequested>(
      _onFollowingsFetch,
      transformer: restartable(),
    );
    on<UserProfileFollowersSubscriptionRequested>(
      _onFollowersSubscriptionRequested,
      transformer: restartable(),
    );
    on<UserProfileFollowUserRequested>(_onFollowUser);
    on<UserProfileRemoveFollowerRequested>(
      _onUserProfileRemoveFollowerRequested,
    );
  }

  final String _userId;
  final UserRepository _userRepository;
  final PostsRepository _postsRepository;

  /// Whose profile this is — widgets below need it to load per-user data.
  String get userId => _userId;

  bool get isOwner => _userId == _userRepository.currentUserId;

  Stream<List<PostBlock>> userPosts({bool small = true, int? limit}) {
    if (small) {
      return _postsRepository
          .postsOf(userId: _userId, limit: limit)
          .map((posts) => posts.map((e) => e.toPostSmallBlock).toList());
    }
    return _postsRepository
        .postsOf(userId: _userId, limit: limit)
        .map((posts) => posts.map((e) => e.toPostLargeBlock).toList());
  }

  /// The owner's posts as raw [Post]s (not blocks) — the grid needs these so a
  /// tapped tile scrolls through only this profile's posts, not everyone's.
  ///
  /// [limit] caps the reactive window for scroll pagination (null = all).
  Stream<List<Post>> userPostsRaw({int? limit}) =>
      _postsRepository.postsOf(userId: _userId, limit: limit);

  Future<void> _onUserProfileSubscriptionRequested(
    UserProfileSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    await emit.forEach(
      isOwner ? _userRepository.user : _userRepository.profile(id: _userId),
      onData: (user) =>
          state.copyWith(user: user, status: UserProfileStatus.userUpdated),
    );
  }

  Future<void> _onUserProfilePostsCountSubscriptionRequested(
    UserProfilePostsCountSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    await emit.forEach(
      _postsRepository.postsAmountOf(userId: _userId),
      onData: (postsCount) => state.copyWith(postsCount: postsCount),
    );
  }

  Future<void> _onUserProfileFollowingsCountSubscriptionRequested(
    UserProfileFollowingsCountSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    await emit.forEach(
      _userRepository.followingsCountOf(userId: _userId),
      onData: (followingsCount) =>
          state.copyWith(followingsCount: followingsCount),
    );
  }

  Future<void> _onUserProfileFollowersCountSubscriptionRequested(
    UserProfileFollowersCountSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    await emit.forEach(
      _userRepository.followersCountOf(userId: _userId),
      onData: (followersCount) =>
          state.copyWith(followersCount: followersCount),
    );
  }

  Stream<bool> followingStatus({String? followerId}) =>
      _userRepository.followingStatus(userId: _userId).asBroadcastStream();

  /// `none` / `pending` / `accepted` — drives the tri-state Follow button
  /// (Follow → Requested → Following) on a private account.
  Stream<String> followState({String? followerId}) =>
      _userRepository
          .followState(userId: _userId, followerId: followerId)
          .asBroadcastStream();

  Future<void> _onUserProfileUpdateRequested(
    UserProfileUpdateRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      if (event.bio != null) {
        await _userRepository.updateUserBio(userId: _userId, bio: event.bio!);
      } else {
        await _userRepository.updateUser(
          email: event.email,
          username: event.username,
          avatarUrl: event.avatarUrl,
          fullName: event.fullName,
          pushToken: event.pushToken,
          birthday: event.birthday,
          telegram: event.telegram,
          website: event.website,
          instagram: event.instagram,
          gender: event.gender,
          clearAvatar: event.clearAvatar,
        );
      }
      emit(state.copyWith(status: UserProfileStatus.userUpdated));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: UserProfileStatus.userUpdateFailed));
    }
  }

  Future<void> _onFollowersFetch(
    UserProfileFetchFollowersRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      final followers = await _userRepository.getFollowers(userId: _userId);
      emit(state.copyWith(followers: followers));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onFollowingsFetch(
    UserProfileFetchFollowingsRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      final followings = await _userRepository.getFollowings(
        userId: _userId,
        limit: event.limit,
      );
      emit(state.copyWith(followings: followings));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onFollowersSubscriptionRequested(
    UserProfileFollowersSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    await emit.forEach(
      _userRepository.followers(userId: _userId, limit: event.limit),
      onData: (followers) => state.copyWith(followers: followers),
    );
  }

  Future<void> _onFollowUser(
    UserProfileFollowUserRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      await _userRepository.follow(followToId: event.userId ?? _userId);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onUserProfileRemoveFollowerRequested(
    UserProfileRemoveFollowerRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    try {
      await _userRepository.removeFollower(id: event.userId ?? _userId);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}

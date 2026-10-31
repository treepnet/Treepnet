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
       super(
         UserProfileState.initial(
           access:
               (userId ?? userRepository.currentUserId) ==
                   userRepository.currentUserId
               ? ProfileAccess.visible
               : ProfileAccess.loading,
         ),
       ) {
    // Someone else's profile syncs only while it is open (the user's own and
    // those of the people they follow always do).
    _scope = _userRepository.profileScope(_userId);
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
    on<UserProfileAccessSubscriptionRequested>(
      _onAccessSubscriptionRequested,
    );
    if (!isOwner) add(const UserProfileAccessSubscriptionRequested());
  }

  /// What [ProfileAccess] is worked out from, as each arrives: whether the
  /// profile's owner blocked the viewer, whether the viewer follows them
  /// (accepted), and whether the profile has synced at all (the user's own
  /// and their followings' always have; anyone else's comes with [_scope]).
  bool? _blockedByOwner;
  bool? _following;
  bool _scopeSynced = false;

  ProfileAccess _accessFor(User user) {
    if (isOwner) return ProfileAccess.visible;
    final blocked = _blockedByOwner;
    if (blocked == null) return ProfileAccess.loading;
    if (blocked) return ProfileAccess.locked;
    // No profile yet: still syncing — or, once synced, there is none.
    if (user.isAnonymous) {
      return _scopeSynced ? ProfileAccess.visible : ProfileAccess.loading;
    }
    if (!user.isPrivate) return ProfileAccess.visible;
    final following = _following;
    if (following == null) return ProfileAccess.loading;
    return following ? ProfileAccess.visible : ProfileAccess.locked;
  }

  /// Watched once here: the page used to open these streams in `build`, so
  /// every rebuild (each frame of a tab change) started them again from
  /// "not following" — the lock flashed and the map and posts were rebuilt.
  Future<void> _onAccessSubscriptionRequested(
    UserProfileAccessSubscriptionRequested event,
    Emitter<UserProfileState> emit,
  ) async {
    final me = _userRepository.currentUserId ?? '';
    await Future.wait([
      emit.forEach<bool>(
        _userRepository.isBlocked(userId: _userId, otherUserId: me),
        onData: (blocked) {
          _blockedByOwner = blocked;
          return state.copyWith(access: _accessFor(state.user));
        },
      ),
      emit.forEach<bool>(
        _userRepository.followingStatus(userId: _userId),
        onData: (following) {
          _following = following;
          return state.copyWith(access: _accessFor(state.user));
        },
      ),
      emit.forEach<void>(
        Stream.fromFuture(_scope.synced),
        onData: (_) {
          _scopeSynced = true;
          return state.copyWith(access: _accessFor(state.user));
        },
      ),
    ]);
  }

  final String _userId;
  final UserRepository _userRepository;
  final PostsRepository _postsRepository;
  late final SyncScope _scope;

  @override
  Future<void> close() {
    _scope.close();
    return super.close();
  }

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
      onData: (user) => state.copyWith(
        user: user,
        status: UserProfileStatus.userUpdated,
        access: _accessFor(user),
      ),
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
  Stream<String> followState({String? followerId}) => _userRepository
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

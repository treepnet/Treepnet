part of 'user_profile_bloc.dart';

enum UserProfileStatus { initial, userUpdated, userUpdateFailed }

/// Whether the viewer sees the profile's map and posts: [visible] for its
/// owner, a public account or an accepted follower; [locked] for a private
/// account they don't follow; [blockedByOwner] when its owner blocked them
/// (shown as a private account, without Follow / Message: the block isn't
/// revealed); [blockedByMe] when they blocked its owner (a notice with
/// Unblock, no Follow / Message); [loading] until that is known (rather than
/// flashing the lock).
enum ProfileAccess { loading, visible, locked, blockedByOwner, blockedByMe }

/// Where the followers or followings list is: a page on its way ([loading]),
/// arrived ([done]) or refused ([failed], offered again).
enum FollowListStatus { loading, done, failed }

class UserProfileState extends Equatable {
  const UserProfileState._({
    required this.status,
    required this.user,
    required this.followings,
    required this.followers,
    required this.postsCount,
    required this.followingsCount,
    required this.followersCount,
    required this.access,
    this.followersStatus = FollowListStatus.loading,
    this.followingsStatus = FollowListStatus.loading,
    this.followersEnd = false,
    this.followingsEnd = false,
  });

  const UserProfileState.initial({ProfileAccess access = ProfileAccess.loading})
    : this._(
        status: UserProfileStatus.initial,
        user: User.anonymous,
        followers: const [],
        followings: const [],
        postsCount: 0,
        followersCount: 0,
        followingsCount: 0,
        access: access,
      );

  final UserProfileStatus status;
  final User user;
  final List<User> followings;
  final List<User> followers;
  final int postsCount;
  final int followingsCount;
  final int followersCount;
  final ProfileAccess access;
  final FollowListStatus followersStatus;
  final FollowListStatus followingsStatus;

  /// The whole list is loaded: no more pages.
  final bool followersEnd;
  final bool followingsEnd;

  @override
  List<Object> get props => [
    access,
    status,
    user,
    followings,
    followers,
    postsCount,
    followingsCount,
    followersCount,
    followersStatus,
    followingsStatus,
    followersEnd,
    followingsEnd,
  ];

  UserProfileState copyWith({
    UserProfileStatus? status,
    User? user,
    List<User>? followings,
    List<User>? followers,
    int? postsCount,
    int? followingsCount,
    int? followersCount,
    ProfileAccess? access,
    FollowListStatus? followersStatus,
    FollowListStatus? followingsStatus,
    bool? followersEnd,
    bool? followingsEnd,
  }) {
    return UserProfileState._(
      access: access ?? this.access,
      status: status ?? this.status,
      user: user ?? this.user,
      followings: followings ?? this.followings,
      followers: followers ?? this.followers,
      postsCount: postsCount ?? this.postsCount,
      followingsCount: followingsCount ?? this.followingsCount,
      followersCount: followersCount ?? this.followersCount,
      followersStatus: followersStatus ?? this.followersStatus,
      followingsStatus: followingsStatus ?? this.followingsStatus,
      followersEnd: followersEnd ?? this.followersEnd,
      followingsEnd: followingsEnd ?? this.followingsEnd,
    );
  }
}

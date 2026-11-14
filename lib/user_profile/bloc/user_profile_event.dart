// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'user_profile_bloc.dart';

sealed class UserProfileEvent extends Equatable {
  const UserProfileEvent();

  @override
  List<Object> get props => [];
}

/// Who may see the profile's content: watched once, for the bloc's life (see
/// [ProfileAccess]).
final class UserProfileAccessSubscriptionRequested extends UserProfileEvent {
  const UserProfileAccessSubscriptionRequested();
}

final class UserProfileUpdateRequested extends UserProfileEvent {
  const UserProfileUpdateRequested({
    this.fullName,
    this.username,
    this.avatarUrl,
    this.birthday,
    this.website,
    this.gender,
    this.clearAvatar = false,
  });

  final String? fullName;
  final String? username;
  final String? avatarUrl;
  final String? birthday;
  final String? website;
  final String? gender;

  /// Takes the photo off the profile. Needed because [avatarUrl] being null
  /// means "unchanged", so it cannot express removal on its own.
  final bool clearAvatar;
}

final class UserProfileSubscriptionRequested extends UserProfileEvent {
  const UserProfileSubscriptionRequested({this.userId});

  final String? userId;
}

final class UserProfilePostsCountSubscriptionRequested
    extends UserProfileEvent {
  const UserProfilePostsCountSubscriptionRequested();
}

final class UserProfileFollowingsCountSubscriptionRequested
    extends UserProfileEvent {
  const UserProfileFollowingsCountSubscriptionRequested();
}

final class UserProfileFollowersCountSubscriptionRequested
    extends UserProfileEvent {
  const UserProfileFollowersCountSubscriptionRequested();
}

final class UserProfileFetchFollowersRequested extends UserProfileEvent {
  const UserProfileFetchFollowersRequested({this.userId});

  final String? userId;
}

final class UserProfileFetchFollowingsRequested extends UserProfileEvent {
  const UserProfileFetchFollowingsRequested({this.userId, this.limit});

  final String? userId;

  /// Reactive-window size for scroll pagination; null = all.
  final int? limit;
}

/// The followers list: its first page, then the pages shown again whenever
/// someone follows or is removed. Again on Retry.
final class UserProfileFollowersSubscriptionRequested extends UserProfileEvent {
  const UserProfileFollowersSubscriptionRequested();
}

/// The followings list's first page (again on Retry).
final class UserProfileFollowingsListRequested extends UserProfileEvent {
  const UserProfileFollowingsListRequested();
}

/// The next page of the followers ([followers]) or followings list, when it
/// has been scrolled to its end.
final class UserProfileFollowListMoreRequested extends UserProfileEvent {
  const UserProfileFollowListMoreRequested({required this.followers});

  final bool followers;
}

/// Follow ([follow], a request for a private account) or unfollow / withdraw
/// the request (not [follow]) — what the tapped button showed it would do.
/// It used to be one toggle, decided from the database at the time.
final class UserProfileFollowUserRequested extends UserProfileEvent {
  const UserProfileFollowUserRequested({this.userId, this.follow = true});

  final String? userId;
  final bool follow;
}

final class UserProfileRemoveFollowerRequested extends UserProfileEvent {
  const UserProfileRemoveFollowerRequested({this.userId});

  final String? userId;
}

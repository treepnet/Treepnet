// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'user_profile_bloc.dart';

sealed class UserProfileEvent extends Equatable {
  const UserProfileEvent();

  @override
  List<Object> get props => [];
}

final class UserProfileUpdateRequested extends UserProfileEvent {
  const UserProfileUpdateRequested({
    this.fullName,
    this.email,
    this.username,
    this.avatarUrl,
    this.pushToken,
    this.bio,
    this.birthday,
    this.telegram,
    this.website,
    this.instagram,
    this.gender,
    this.clearAvatar = false,
  });

  final String? fullName;
  final String? email;
  final String? username;
  final String? avatarUrl;
  final String? pushToken;
  final String? bio;
  final String? birthday;
  final String? telegram;
  final String? website;
  final String? instagram;
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

final class UserProfileFollowersSubscriptionRequested extends UserProfileEvent {
  const UserProfileFollowersSubscriptionRequested({this.limit});

  /// Reactive-window size for scroll pagination; null = all.
  final int? limit;
}

final class UserProfileFollowUserRequested extends UserProfileEvent {
  const UserProfileFollowUserRequested({this.userId});

  final String? userId;
}

final class UserProfileRemoveFollowerRequested extends UserProfileEvent {
  const UserProfileRemoveFollowerRequested({this.userId});

  final String? userId;
}

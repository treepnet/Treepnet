part of 'user_stories_bloc.dart';

sealed class UserStoriesEvent extends Equatable {
  const UserStoriesEvent();

  @override
  List<Object> get props => [];
}

final class UserStoriesSubscriptionRequested extends UserStoriesEvent {
  const UserStoriesSubscriptionRequested(this.userId);

  final String userId;
}

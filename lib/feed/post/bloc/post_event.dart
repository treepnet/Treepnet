part of 'post_bloc.dart';

sealed class PostEvent extends Equatable {
  const PostEvent();

  @override
  List<Object> get props => [];
}

/// Keeps the post's counts, the viewer's liked / saved / following state and
/// the author's badge and places count up to date — from the one query all
/// cards share (PostsRepository.statsOf).
final class PostStatsSubscriptionRequested extends PostEvent {
  const PostStatsSubscriptionRequested({
    required this.ownerId,
    required this.currentUserId,
  });

  final String ownerId;
  final String currentUserId;
}

final class PostUpdateRequested extends PostEvent {
  const PostUpdateRequested({this.caption, this.onPostUpdated});

  final String? caption;
  final ValueSetter<PostBlock>? onPostUpdated;
}

final class PostLikersInFollowingsFetchRequested extends PostEvent {
  const PostLikersInFollowingsFetchRequested();
}

final class PostLikersPageRequested extends PostEvent {
  const PostLikersPageRequested({this.page = 0});

  final int page;
}

final class PostLikeRequested extends PostEvent {
  const PostLikeRequested({this.liked});

  /// The outcome wanted (a double tap only ever likes); null flips it.
  final bool? liked;
}

final class PostBookmarkRequested extends PostEvent {
  const PostBookmarkRequested();
}

final class PostAuthorFollowRequested extends PostEvent {
  const PostAuthorFollowRequested({required this.authorId});

  final String authorId;
}

final class PostDeleteRequested extends PostEvent {
  const PostDeleteRequested();
}


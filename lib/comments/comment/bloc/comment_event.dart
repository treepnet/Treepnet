part of 'comment_bloc.dart';

sealed class CommentEvent extends Equatable {
  const CommentEvent();

  @override
  List<Object?> get props => [];
}

/// The comment's likes and whether you and the post's author liked it.
final class CommentStatsSubscriptionRequested extends CommentEvent {
  const CommentStatsSubscriptionRequested();
}

final class CommentsRepliedCommentsSubscriptionRequested extends CommentEvent {
  const CommentsRepliedCommentsSubscriptionRequested(this.commentId);

  final String commentId;
}

final class CommentLikeRequested extends CommentEvent {
  const CommentLikeRequested();
}

final class CommentDeleteRequested extends CommentEvent {
  const CommentDeleteRequested();
}

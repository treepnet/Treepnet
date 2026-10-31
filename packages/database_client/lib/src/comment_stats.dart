import 'package:flutter/foundation.dart' show immutable;

/// What a comment shows besides its text: its likes, and whether the viewer
/// and the post's author liked it. Read for every comment on screen in one
/// live query (`DatabaseClient.commentStatsOf`) — each comment used to open
/// three queries of its own.
@immutable
class CommentStats {
  /// Creates a [CommentStats].
  const CommentStats({
    required this.likes,
    required this.isLiked,
    required this.isLikedByPostAuthor,
  });

  /// Likes on the comment.
  final int likes;

  /// Whether the viewer liked it.
  final bool isLiked;

  /// Whether the author of the post it's under liked it.
  final bool isLikedByPostAuthor;

  @override
  bool operator ==(Object other) =>
      other is CommentStats &&
      other.likes == likes &&
      other.isLiked == isLiked &&
      other.isLikedByPostAuthor == isLikedByPostAuthor;

  @override
  int get hashCode => Object.hash(likes, isLiked, isLikedByPostAuthor);
}

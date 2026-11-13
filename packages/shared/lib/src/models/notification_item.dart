/// The kind of activity a [NotificationItem] represents.
enum NotificationType {
  /// Someone liked one of the user's posts.
  like,

  /// Someone commented on one of the user's posts.
  comment,

  /// Someone started following the user.
  follow,

  /// Someone asked to follow the user's private account — awaits Accept/Decline.
  followRequest,

  /// Someone sent the user a direct message.
  message,

  /// Someone replied to the user's comment.
  reply,

  /// Someone accepted the user's request to follow them.
  followAccepted,

  /// Someone liked the user's comment.
  commentLike,
}

/// A single entry in the Notifications feed: an [actorUsername] who did
/// something ([type]) to the current user, optionally on a post ([postId]),
/// at [createdAt].
class NotificationItem {
  const NotificationItem({
    required this.type,
    required this.actorId,
    required this.actorUsername,
    this.actorAvatarUrl,
    this.actorFullName,
    this.postId,
    this.postThumbUrl,
    this.content,
    this.createdAt,
  });

  final NotificationType type;
  final String actorId;
  final String actorUsername;
  final String? actorAvatarUrl;
  final String? actorFullName;

  /// The post the like/comment is on (null for follows).
  final String? postId;

  /// A small picture of that post (its grid thumbnail when it has one), read
  /// with the notification — each row used to fetch its whole post.
  final String? postThumbUrl;

  /// The comment text (only for [NotificationType.comment]).
  final String? content;

  final DateTime? createdAt;

  /// The type, or null for one this version doesn't know: such a row is left
  /// out. Every unknown type used to read as a like, so a kind the server
  /// adds later would have said "liked your post".
  static NotificationType? typeFromString(String value) => switch (value) {
    'like' => NotificationType.like,
    'comment' => NotificationType.comment,
    'follow' => NotificationType.follow,
    'follow_request' => NotificationType.followRequest,
    'message' => NotificationType.message,
    'reply' => NotificationType.reply,
    'follow_accepted' => NotificationType.followAccepted,
    'comment_like' => NotificationType.commentLike,
    _ => null,
  };

  /// The types [typeFromString] knows, as stored.
  static const knownTypes = [
    'like',
    'comment',
    'follow',
    'follow_request',
    'message',
    'reply',
    'follow_accepted',
    'comment_like',
  ];
}

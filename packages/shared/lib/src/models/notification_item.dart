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

  /// The comment text (only for [NotificationType.comment]).
  final String? content;

  final DateTime? createdAt;

  static NotificationType typeFromString(String value) {
    switch (value) {
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'follow_request':
        return NotificationType.followRequest;
      case 'message':
        return NotificationType.message;
      default:
        return NotificationType.like;
    }
  }
}

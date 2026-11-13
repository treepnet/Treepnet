import 'package:shared/shared.dart';

/// One row of the notifications list: a notification, or the likes a post got
/// on one day, shown as the newest liker "and [others] more".
class NotificationRow {
  /// Creates a [NotificationRow].
  const NotificationRow(this.item, {this.others = 0});

  /// The notification shown (for likes, the newest).
  final NotificationItem item;

  /// How many other people the row stands for (likes only).
  final int others;
}

/// [items] (newest first) as rows: a post's likes of the same day become one
/// row, where the newest of them was. Each like was a row of its own, so a
/// few liked posts filled the list and pushed comments and follows out of
/// sight (prod: 227 like rows to 43 comments).
///
/// The day is the phone's. The same person liking twice counts once.
List<NotificationRow> notificationRows(List<NotificationItem> items) {
  final rows = <NotificationRow>[];
  // Per post and day: where its row is, and who liked.
  final rowOf = <String, int>{};
  final likers = <String, Set<String>>{};
  for (final item in items) {
    final post = item.postId;
    final time = item.createdAt?.toLocal();
    if (item.type != NotificationType.like || post == null || time == null) {
      rows.add(NotificationRow(item));
      continue;
    }
    final key = '$post ${time.year}-${time.month}-${time.day}';
    final at = rowOf[key];
    if (at == null) {
      rowOf[key] = rows.length;
      likers[key] = {item.actorId};
      rows.add(NotificationRow(item));
    } else if (likers[key]!.add(item.actorId)) {
      rows[at] = NotificationRow(rows[at].item, others: rows[at].others + 1);
    }
  }
  return rows;
}

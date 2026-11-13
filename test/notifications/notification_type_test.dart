import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('each stored kind reads as its own type', () {
    expect(NotificationItem.typeFromString('like'), NotificationType.like);
    expect(
      NotificationItem.typeFromString('comment'),
      NotificationType.comment,
    );
    expect(NotificationItem.typeFromString('reply'), NotificationType.reply);
    expect(
      NotificationItem.typeFromString('follow_accepted'),
      NotificationType.followAccepted,
    );
    expect(
      NotificationItem.typeFromString('comment_like'),
      NotificationType.commentLike,
    );
  });

  test(
    'a kind this version does not know is left out, not shown as a like',
    () {
      // It used to read as "liked your post".
      expect(NotificationItem.typeFromString('story_mention'), isNull);
      expect(NotificationItem.typeFromString(''), isNull);
    },
  );

  test('every known kind is in the list the queries filter by', () {
    for (final kind in NotificationItem.knownTypes) {
      expect(NotificationItem.typeFromString(kind), isNotNull, reason: kind);
    }
  });
}

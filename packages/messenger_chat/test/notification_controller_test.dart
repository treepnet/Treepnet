import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:messenger_chat/data/model/chat_model.dart';
import 'package:messenger_chat/data/model/unread_message_data.dart';

void main() {
  test('NotificationController.add publishes events', () async {
    final controller = NotificationController<ChatModel>();
    final model = ChatModel(
      unreadMessageData: UnreadMessageData(
        content: 'notif',
        isAnswer: false,
        unreadCount: 1,
      ),
    );

    expectLater(controller.stream, emits(model));
    controller.add(model);
  });
}

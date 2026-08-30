import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/service/chat_controller/chat_controller.dart';
import 'package:messenger_chat/data/model/chat_model.dart';
import 'package:messenger_chat/data/model/unread_message_data.dart';

void main() {
  test('ChatController.update emits stream and sets value', () async {
    final controller = ChatController<ChatModel>();
    final model = ChatModel(
      unreadMessageData: UnreadMessageData(
        content: 'hello',
        isAnswer: true,
        unreadCount: 5,
      ),
    );

    expectLater(controller.stream, emits(model));
    controller.update(model);
    expect(controller.value, equals(model));
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/messenger_chat.dart';

void main() {
  test('MessengerChat.onUnreadCount callback receives updates', () async {
    final completer = Completer<int>();
    final sub = MessengerChat.onUnreadCount((count) {
      if (!completer.isCompleted) completer.complete(count);
    });
    final model = ChatModel(
      unreadMessageData: UnreadMessageData(
        content: 'msg',
        isAnswer: true,
        unreadCount: 7,
      ),
    );
    MessengerChat.controller.update(model);
    final result = await completer.future.timeout(const Duration(seconds: 2));
    expect(result, 7);
    await sub.cancel();
  });

  test('MessengerChat.onChatSummary callback receives ChatModel', () async {
    final completer = Completer<ChatModel>();
    final sub = MessengerChat.onChatSummary((summary) {
      if (!completer.isCompleted) completer.complete(summary);
    });
    final model = ChatModel(
      unreadMessageData: UnreadMessageData(
        content: 'summary',
        isAnswer: false,
        unreadCount: 2,
      ),
    );
    MessengerChat.controller.update(model);
    final result = await completer.future.timeout(const Duration(seconds: 2));
    expect(result.unreadMessageData.content, 'summary');
    await sub.cancel();
  });
}

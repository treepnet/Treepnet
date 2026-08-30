import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/data/model/chat_model.dart';
import 'package:messenger_chat/data/model/unread_message_data.dart';

void main() {
  test('unread.count payload maps to ChatModel correctly', () {
    final data = {
      'unreadCount': 3,
      'lastMessage': {'content': 'Hello', 'isAnswer': 1},
    };
    final model = ChatModel.fromJson(data);
    expect(model.unreadMessageData.unreadCount, 3);
    expect(model.unreadMessageData.content, 'Hello');
    expect(model.unreadMessageData.isAnswer, true);
  });

  test('chat.summary payload maps to ChatModel correctly', () {
    final data = {
      'unreadCount': 0,
      'lastMessage': {'content': 'Admin reply', 'isAnswer': 1},
    };
    final model = ChatModel.fromJson(data);
    expect(model.unreadMessageData.unreadCount, 0);
    expect(model.unreadMessageData.content, 'Admin reply');
    expect(model.unreadMessageData.isAnswer, true);
  });

  test('UnreadMessageData.toJson produces expected structure', () {
    final unread = UnreadMessageData(
      content: 'hi',
      isAnswer: false,
      unreadCount: 5,
    );
    final json = unread.toJson();
    expect(json['content'], 'hi');
    expect(json['isAnswer'], false);
    expect(json['unreadCount'], 5);
  });
}

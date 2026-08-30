import 'package:messenger_chat/data/model/unread_message_data.dart';

class ChatModel {
  ChatModel({required this.unreadMessageData});

  final UnreadMessageData unreadMessageData;

  ChatModel copyWith({UnreadMessageData? unreadMessageData}) =>
      ChatModel(unreadMessageData: unreadMessageData ?? this.unreadMessageData);

  static ChatModel fromJson(dynamic json) =>
      ChatModel(unreadMessageData: UnreadMessageData.fromJson(json));
}

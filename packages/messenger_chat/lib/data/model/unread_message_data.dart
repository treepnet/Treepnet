class UnreadMessageData {
  UnreadMessageData({required this.content, required this.isAnswer, required this.unreadCount});

  final String content;
  final bool isAnswer;
  final int unreadCount;

  UnreadMessageData copyWith({String? content, bool? isAnswer, int? unreadCount}) =>
      UnreadMessageData(
        content: content ?? this.content,
        isAnswer: isAnswer ?? this.isAnswer,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  static UnreadMessageData fromJson(dynamic json) {
    final Map<String, dynamic> lastMessage = json['lastMessage'] ?? {};
    return UnreadMessageData(
      content: lastMessage['content'] ?? '',
      isAnswer: (lastMessage['isAnswer'] ?? 0) == 1 ? true : false,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content,
    'isAnswer': isAnswer,
    'unreadCount': unreadCount,
  };
}

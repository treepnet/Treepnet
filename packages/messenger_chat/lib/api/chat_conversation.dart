part of messenger_chat;

/// Chat ro'yxatidagi bitta suhbat.
class ChatConversation extends Equatable {
  const ChatConversation({
    required this.id,
    required this.peer,
    this.lastMessage = '',
    this.lastMessageKind = ChatMessageKind.text,
    this.lastMessageAt,
    this.lastMessageIsMine = false,
    this.lastMessageIsRead = false,
    this.unreadCount = 0,
    this.isPinned = false,
  });

  /// Suhbat identifikatori - chat ekranini ochishda ishlatiladi.
  final String id;

  /// Suhbatdosh (1:1 suhbat uchun).
  final ChatUser peer;

  /// Oxirgi xabar matni. Media xabarlar uchun bo'sh qoldirilishi mumkin -
  /// UI [lastMessageKind] ga qarab "Rasm", "Ovozli xabar" kabi matn chizadi.
  final String lastMessage;

  final ChatMessageKind lastMessageKind;

  final DateTime? lastMessageAt;

  /// Oxirgi xabarni o'zimiz yuborganmizmi - yonida o'qildi belgisi
  /// ko'rsatiladi.
  final bool lastMessageIsMine;

  final bool lastMessageIsRead;

  /// O'qilmagan xabarlar soni.
  final int unreadCount;

  final bool isPinned;

  ChatConversation copyWith({
    String? id,
    ChatUser? peer,
    String? lastMessage,
    ChatMessageKind? lastMessageKind,
    DateTime? lastMessageAt,
    bool? lastMessageIsMine,
    bool? lastMessageIsRead,
    int? unreadCount,
    bool? isPinned,
  }) => ChatConversation(
    id: id ?? this.id,
    peer: peer ?? this.peer,
    lastMessage: lastMessage ?? this.lastMessage,
    lastMessageKind: lastMessageKind ?? this.lastMessageKind,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    lastMessageIsMine: lastMessageIsMine ?? this.lastMessageIsMine,
    lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
    unreadCount: unreadCount ?? this.unreadCount,
    isPinned: isPinned ?? this.isPinned,
  );

  @override
  List<Object?> get props => [
    id,
    peer,
    lastMessage,
    lastMessageKind,
    lastMessageAt,
    lastMessageIsMine,
    lastMessageIsRead,
    unreadCount,
    isPinned,
  ];
}

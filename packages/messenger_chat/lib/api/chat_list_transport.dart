part of messenger_chat;

/// Chat ro'yxati hodisalari.
sealed class ChatListEvent {
  const ChatListEvent();
}

/// Suhbat qo'shildi yoki yangilandi (yangi xabar keldi, o'qildi, nom o'zgardi).
///
/// Ro'yxat suhbatni topib almashtiradi, topolmasa - yuqoriga qo'shadi.
class ChatConversationUpserted extends ChatListEvent {
  const ChatConversationUpserted(this.conversation);
  final ChatConversation conversation;
}

/// Suhbat o'chirildi.
class ChatConversationRemoved extends ChatListEvent {
  const ChatConversationRemoved(this.conversationId);
  final String conversationId;
}

/// Suhbatdoshning onlayn holati o'zgardi.
class ChatPeerPresenceChanged extends ChatListEvent {
  const ChatPeerPresenceChanged({
    required this.peerId,
    required this.isOnline,
    this.lastSeen,
  });

  final String peerId;
  final bool isOnline;
  final DateTime? lastSeen;
}

/// Ulanish holati o'zgardi.
class ChatListConnectionChanged extends ChatListEvent {
  const ChatListConnectionChanged(this.status);
  final ChatConnectionStatus status;
}

/// Chat ro'yxati uchun transport shartnomasi.
///
/// [ChatTransport] bitta suhbat bilan ishlaydi; bu esa suhbatlar ro'yxatini
/// boshqaradi. Ikkalasi mustaqil: ro'yxat ekranida faqat shu transport,
/// suhbat ochilganda esa o'sha suhbat uchun [ChatTransport] ishlatiladi.
abstract class ChatListTransport {
  /// Ro'yxat ekrani ochilganda chaqiriladi (socketni ulash uchun).
  Future<void> connect();

  /// Suhbatlarni sahifalab yuklaydi. [page] 1 dan boshlanadi.
  Future<ChatConversationPage> loadConversations({
    required int page,
    required int size,
  });

  /// Real vaqt hodisalari - yangi xabar kelganda ro'yxat shu orqali
  /// yangilanadi.
  Stream<ChatListEvent> get events;

  /// Ekran yopilganda resurslarni bo'shatadi.
  Future<void> dispose();
}

/// Suhbatlar ro'yxatining bitta sahifasi.
class ChatConversationPage {
  const ChatConversationPage({
    required this.conversations,
    required this.hasMore,
  });

  final List<ChatConversation> conversations;
  final bool hasMore;
}

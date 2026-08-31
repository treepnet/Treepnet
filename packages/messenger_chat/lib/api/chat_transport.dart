part of messenger_chat;

/// Ilova beradigan maxsus xabar chizuvchisi.
///
/// Har bir matn xabari chizilishdan oldin chaqiriladi. `null` qaytarsa - oddiy
/// matn chiziladi; widget qaytarsa - o'sha widget matn o'rniga chiziladi.
/// Ilova bu orqali maxsus formatdagi matnlarni (masalan ulashilgan post/story
/// havolasini) chiroyli kartochka qilib ko'rsatadi. [content] - xabar matni.
typedef SharedMessageBuilder =
    Widget? Function(BuildContext context, String content);

/// Xabar turi. Plagin UI ni shunga qarab tanlaydi.
enum ChatMessageKind { text, photo, video, voice, file }

/// Javob berilayotgan xabarning qisqa nusxasi (iqtibos). Xabar bilan birga
/// saqlanadi, shuning uchun eski xabar yuklanmagan bo'lsa ham iqtibos ko'rinadi.
class ChatReplyInfo {
  const ChatReplyInfo({
    required this.messageId,
    required this.content,
    required this.senderId,
  });

  /// Javob berilayotgan xabarning serverdagi identifikatori.
  final String messageId;

  /// Uning matni (yoki media uchun qisqa yorliq).
  final String content;

  /// Uni kim yuborgani - iqtibosda "Siz" yoki suhbatdosh ismini ko'rsatish uchun.
  final String senderId;
}

/// Transportdan kelgan (yoki tarixdan yuklangan) bitta xabar.
class ChatIncomingMessage {
  const ChatIncomingMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.content,
    required this.sentAt,
    this.clientKey,
    this.waveformUrl,
    this.thumbnailUrl,
    this.duration,
    this.size,
    this.isRead = false,
    this.senderName,
    this.replyTo,
  });

  /// Serverdagi barqaror identifikator.
  final String id;

  /// Kim yuborgani. `ChatUser.id` bilan solishtiriladi.
  final String senderId;

  final ChatMessageKind kind;

  /// Matn xabari uchun matn, media uchun to'liq yuklab olish manzili.
  final String content;

  final DateTime sentAt;

  /// Ilova yuborishda bergan kalit. Optimistik xabarni serverdagi nusxa bilan
  /// almashtirish uchun kerak - `null` bo'lsa xabar yangi deb qo'shiladi.
  final String? clientKey;

  /// Ovozli xabar to'lqin shakli (SVG) manzili.
  final String? waveformUrl;

  /// Video uchun oldindan ko'rish rasmi (thumbnail) manzili.
  ///
  /// Berilmasa video xabarda bo'sh joy ko'rinadi - server odatda yuklashda
  /// avtomatik hosil qiladi.
  final String? thumbnailUrl;

  /// Ovoz/video davomiyligi (soniyalarda, matn ko'rinishida).
  final String? duration;

  /// Fayl hajmi - hujjat xabarlarida ko'rsatiladi.
  final String? size;

  final bool isRead;

  /// Guruh suhbatlarida jo'natuvchi ismi. 1:1 da kerak emas.
  final String? senderName;

  /// Bu xabar javob bo'lsa - javob berilgan xabarning iqtibosi.
  final ChatReplyInfo? replyTo;
}

/// Tarixning bitta sahifasi.
class ChatHistoryPage {
  const ChatHistoryPage({required this.messages, required this.hasMore});

  /// Yangidan eskiga tartibda.
  final List<ChatIncomingMessage> messages;

  /// Yana eski xabarlar bormi.
  final bool hasMore;
}

/// Ilova yuborishi kerak bo'lgan xabar.
class ChatOutgoingMessage {
  const ChatOutgoingMessage({
    required this.clientKey,
    required this.kind,
    required this.content,
    this.thumbnailUrl,
    this.duration,
    this.size,
    this.replyTo,
  });

  /// Plagin yaratadigan noyob kalit. Server uni `clientKey` sifatida qaytarsa,
  /// optimistik xabar dublikat bo'lmaydi.
  final String clientKey;

  final ChatMessageKind kind;

  /// Matn yoki yuklangan faylning manzili.
  final String content;

  /// Video uchun thumbnail manzili.
  final String? thumbnailUrl;

  final String? duration;
  final String? size;

  /// Bu xabar javob bo'lsa - javob berilayotgan xabarning iqtibosi.
  final ChatReplyInfo? replyTo;
}

/// Fayl yuklash natijasi.
class ChatUploadResult {
  const ChatUploadResult({
    required this.url,
    this.waveformUrl,
    this.thumbnailUrl,
    this.duration,
    this.size,
  });

  final String url;
  final String? waveformUrl;

  /// Video uchun thumbnail manzili.
  final String? thumbnailUrl;
  final String? duration;
  final String? size;
}

/// Transport hodisalari.
sealed class ChatTransportEvent {
  const ChatTransportEvent();
}

/// Yangi xabar keldi (o'zimiz yuborgan xabarning tasdig'i ham shu orqali keladi).
class ChatMessageReceived extends ChatTransportEvent {
  const ChatMessageReceived(this.message);
  final ChatIncomingMessage message;
}

/// Suhbatdosh yozmoqda / to'xtadi.
class ChatTypingChanged extends ChatTransportEvent {
  const ChatTypingChanged({
    required this.userId,
    required this.isTyping,
    this.kind,
  });
  final String userId;
  final bool isTyping;

  /// Ovoz yozayotgan bo'lsa `ChatMessageKind.voice` - UI buni alohida
  /// ko'rsatishi mumkin.
  final ChatMessageKind? kind;
}

/// Xabar(lar) o'qildi.
class ChatMessagesRead extends ChatTransportEvent {
  const ChatMessagesRead({this.messageId, this.all = false});

  /// Aniq bitta xabar o'qilgan bo'lsa uning identifikatori.
  final String? messageId;

  /// Suhbatdagi barcha xabarlar o'qilgan bo'lsa `true`.
  final bool all;
}

/// Suhbatdosh onlayn/oflayn bo'ldi.
///
/// Ilova buni yuborishi ixtiyoriy - yuborilmasa app bar faqat ulanish
/// holatini ko'rsatadi.
class ChatPeerPresence extends ChatTransportEvent {
  const ChatPeerPresence({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
  });

  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
}

/// Ulanish holati o'zgardi.
class ChatConnectionChanged extends ChatTransportEvent {
  const ChatConnectionChanged(this.status);
  final ChatConnectionStatus status;
}

/// Chat UI va ilovaning backendi o'rtasidagi yagona shartnoma.
///
/// Plagin tarmoq haqida hech narsa bilmaydi: HTTP, WebSocket, Firebase yoki
/// boshqa har qanday transport shu interfeys ortida bo'lishi mumkin. Ilova
/// faqat shu sinfni amalga oshiradi va [MessengerChat.init] ga uzatadi.
///
/// Namuna uchun `example/lib/rest_socket_transport.dart` ga qarang.
abstract class ChatTransport {
  /// Suhbat ochilganda bir marta chaqiriladi.
  Future<void> connect();

  /// Tarixni sahifalab yuklaydi. [page] 1 dan boshlanadi.
  Future<ChatHistoryPage> loadHistory({required int page, required int size});

  /// Xabarni yuboradi. Xato bo'lsa istisno tashlash kerak - plagin uni
  /// oflayn navbatga (outbox) qo'yadi va tarmoq tiklanganda qayta yuboradi.
  Future<void> send(ChatOutgoingMessage message);

  /// Media faylni yuklaydi va uning manzilini qaytaradi.
  Future<ChatUploadResult> uploadAttachment({
    required String filePath,
    required String clientKey,
    required ChatMessageKind kind,
    void Function(int sent, int total)? onProgress,
  });

  /// "Yozmoqda" holatini bildiradi.
  Future<void> sendTyping({required bool isTyping, ChatMessageKind? kind});

  /// Xabarlarni o'qilgan deb belgilaydi. [messageId] berilmasa - hammasi.
  Future<void> markRead({String? messageId});

  /// Kiruvchi hodisalar oqimi.
  Stream<ChatTransportEvent> get events;

  /// Suhbat yopilganda resurslarni bo'shatadi.
  Future<void> dispose();
}

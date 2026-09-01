part of messenger_chat;

/// Plaginning ishlash davridagi holati: kim yozmoqda va qaysi transport
/// ishlatilmoqda.
///
/// [MessengerChat.init] chaqirilganda to'ldiriladi va suhbat yopilguncha
/// o'zgarmaydi.
class _ChatRuntime {
  _ChatRuntime._();

  static final _ChatRuntime instance = _ChatRuntime._();

  ChatTransport? _transport;
  ChatUser? _me;
  ChatUser? _peer;

  /// Suhbatdoshning joriy holati - app bar shunga obuna bo'ladi.
  final ValueNotifier<ChatUser?> peerNotifier = ValueNotifier<ChatUser?>(null);
  ChatFeatures _features = const ChatFeatures();

  /// Ilova bergan maxsus xabar (masalan, ulashilgan post/story) chizuvchisi.
  /// Matn xabari uchun `null` bo'lmagan widget qaytarsa, oddiy matn o'rniga
  /// o'sha chiziladi. Tarmoq/model o'zgarmaydi - xabar oddiy matn bo'lib
  /// qoladi, faqat ko'rinishi boshqacha.
  SharedMessageBuilder? sharedMessageBuilder;

  /// Ilova bergan reply/quote matni formatlovchi: ulashilgan post/story kabi
  /// maxsus xabar uchun qisqa yorliq ("📷 Post") qaytaradi, oddiy matn uchun
  /// null. Reply-iqtibosda xom `treepnet:share:...` matn o'rniga ishlatiladi.
  String? Function(String content)? sharedReplyPreview;

  /// Ilova bergan transport.
  ///
  /// [MessengerChat.init] chaqirilmagan bo'lsa - dasturchi xatosi, shuning
  /// uchun jimgina davom etmasdan aniq xabar bilan to'xtatamiz.
  ChatTransport get transport {
    final value = _transport;
    if (value == null) {
      throw StateError(
        'MessengerChat.init(transport: ..., me: ...) chaqirilmagan. '
        'Chat ekranini ochishdan oldin uni chaqiring.',
      );
    }
    return value;
  }

  /// Hozirgi foydalanuvchi.
  ChatUser get me {
    final value = _me;
    if (value == null) {
      throw StateError(
        'MessengerChat.init(transport: ..., me: ...) chaqirilmagan. '
        'Chat ekranini ochishdan oldin uni chaqiring.',
      );
    }
    return value;
  }

  /// Ruxsat etilgan xabar turlari.
  ChatFeatures get features => _features;

  /// Suhbatdosh. Ekran ochilganda ornatiladi.
  ChatUser? get peer => _peer;

  bool get isInitialized => _transport != null && _me != null;

  void configure({
    required ChatTransport transport,
    required ChatUser me,
    ChatFeatures? features,
    SharedMessageBuilder? sharedMessageBuilder,
    String? Function(String content)? sharedReplyPreview,
  }) {
    if (features != null) _features = features;
    _transport = transport;
    _me = me;
    this.sharedMessageBuilder = sharedMessageBuilder;
    this.sharedReplyPreview = sharedReplyPreview;
  }

  void setPeer(ChatUser? value) {
    _peer = value;
    peerNotifier.value = value;
  }

  /// Presence hodisasi kelganda suhbatdosh holatini yangilaydi.
  void updatePeerPresence({
    required String userId,
    required bool isOnline,
    DateTime? lastSeen,
  }) {
    final current = _peer;
    if (current == null || current.id != userId) return;
    setPeer(current.copyWith(isOnline: isOnline, lastSeen: lastSeen));
  }

  Future<void> reset() async {
    await _transport?.dispose();
    _transport = null;
    _me = null;
    _peer = null;
    sharedMessageBuilder = null;
    sharedReplyPreview = null;
    peerNotifier.value = null;
  }
}

part of messenger_chat;

/// Transport bilan UI o'rtasidagi ko'prik.
///
/// Ilgari bu yerda to'g'ridan-to'g'ri socket.io klienti turardi. Endi plagin
/// tarmoq haqida hech narsa bilmaydi: [ChatTransport.events] oqimini tinglaydi
/// va chiqadigan xabarlarni [ChatTransport.send] ga uzatadi.
///
/// Oflayn navbat (outbox) shu yerda qoladi - transport xato tashlasa, xabar
/// saqlanadi va ulanish tiklanganda qayta yuboriladi.
class _ChatSocket {
  static ChatTransport? _transport;
  static StreamSubscription<ChatTransportEvent>? _subscription;
  static ChatCubit? _cubit;

  static bool get isConnected => _transport != null;

  /// Suhbat ekrani ochilganda chaqiriladi.
  static Future<void> connect({required ChatCubit cubit}) async {
    await dispose();

    final transport = _ChatRuntime.instance.transport;
    _transport = transport;
    _cubit = cubit;

    MessengerChat.controller.updateConnection(ChatConnectionStatus.connecting);

    _subscription = transport.events.listen(
      _handleEvent,
      onError: (Object e) {
        _ChatLogger.failure('⛔️ Transport xatolik: $e');
        MessengerChat.controller.updateConnection(ChatConnectionStatus.error);
      },
    );

    try {
      await transport.connect();
      MessengerChat.controller.updateConnection(ChatConnectionStatus.connected);
      await _resendOutbox();
    } catch (e) {
      _ChatLogger.failure('⛔️ Transport ulanmadi: $e');
      MessengerChat.controller.updateConnection(ChatConnectionStatus.error);
    }
  }

  static void _handleEvent(ChatTransportEvent event) {
    final cubit = _cubit;
    if (cubit == null) return;

    switch (event) {
      case ChatMessageReceived(:final message):
        _ChatLogger.print('💬 Xabar keldi: ${message.id}');
        final model = _MessageModel.fromIncoming(
          message,
          myId: _ChatRuntime.instance.me.id,
        );
        // O'zimiz yuborgan xabarning tasdig'i bo'lsa - optimistik nusxani
        // yangilaymiz, aks holda yangi xabar sifatida qo'shamiz.
        if (model.isMine && model.key.isNotEmpty) {
          _OutboxService().removeMessage(model.key);
          cubit.updateMessage(model);
        } else {
          cubit.addMessage(model);
        }

      case ChatTypingChanged(:final isTyping, :final kind):
        cubit.typing(
          isTyping: isTyping,
          typingType: kind == null
              ? ''
              : _ContentType.fromKind(kind).name,
          typingName: _ChatRuntime.instance.peer?.name,
        );

      case ChatMessagesRead(:final messageId, :final all):
        if (all) {
          cubit.markAllMessagesAsRead();
        } else if (messageId != null) {
          cubit.markMessageAsRead(messageId);
        }

      case ChatPeerPresence(:final userId, :final isOnline, :final lastSeen):
        _ChatRuntime.instance.updatePeerPresence(
          userId: userId,
          isOnline: isOnline,
          lastSeen: lastSeen,
        );

      case ChatConnectionChanged(:final status):
        MessengerChat.controller.updateConnection(status);
        if (status == ChatConnectionStatus.connected) {
          unawaited(_resendOutbox());
        }
    }
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _transport = null;
    _cubit = null;

    if (!MessengerChat.controller.connectionStreamIsClosed) {
      MessengerChat.controller.updateConnection(
        ChatConnectionStatus.disconnected,
      );
    }
  }

  /// Xabarni yuboradi. Xato bo'lsa outbox'ga tushadi va keyin qayta yuboriladi.
  static Future<void> send(
    ChatOutgoingMessage message, {
    void Function()? onSuccess,
    void Function(Object error)? onError,
  }) async {
    final transport = _transport;
    if (transport == null) {
      _ChatLogger.failure('⛔️ Transport ulanmagan, xabar navbatga qo\'yildi');
      _OutboxService().addMessage(message.clientKey, _encode(message));
      onError?.call(StateError(_AppTexts.socketConnectionNot));
      return;
    }

    try {
      await transport.send(message);
      _OutboxService().removeMessage(message.clientKey);
      onSuccess?.call();
    } catch (e) {
      _ChatLogger.failure('📦 Yuborilmadi, navbatga qo\'yildi: $e');
      _OutboxService().addMessage(message.clientKey, _encode(message));
      onError?.call(e);
    }
  }

  static Future<void> sendTyping({
    required bool isTyping,
    ChatMessageKind? kind,
  }) async {
    try {
      await _transport?.sendTyping(isTyping: isTyping, kind: kind);
    } catch (e) {
      // "Yozmoqda" belgisi muhim emas - xato bo'lsa jimgina o'tkazamiz.
      _ChatLogger.print('typing yuborilmadi: $e');
    }
  }

  static Future<void> markRead({String? messageId}) async {
    try {
      await _transport?.markRead(messageId: messageId);
    } catch (e) {
      _ChatLogger.print('markRead yuborilmadi: $e');
    }
  }

  /// Navbatdagi xabarlarni qayta yuboradi.
  static Future<void> _resendOutbox() async {
    final outbox = _OutboxService();
    if (outbox.isEmpty) return;

    _ChatLogger.print('♻️ Navbatdagi xabarlar qayta yuborilmoqda...');
    for (final data in outbox.getAll()) {
      final message = _decode(data);
      if (message == null) continue;
      await send(message);
    }
  }

  static Map<String, dynamic> _encode(ChatOutgoingMessage message) => {
    'key': message.clientKey,
    'kind': message.kind.name,
    'content': message.content,
    'duration': message.duration,
    'size': message.size,
  };

  static ChatOutgoingMessage? _decode(Map<dynamic, dynamic> data) {
    final key = data['key'] as String?;
    final content = data['content'] as String?;
    if (key == null || content == null) return null;

    return ChatOutgoingMessage(
      clientKey: key,
      kind: ChatMessageKind.values.firstWhere(
        (k) => k.name == data['kind'],
        orElse: () => ChatMessageKind.text,
      ),
      content: content,
      duration: data['duration'] as String?,
      size: data['size'] as String?,
    );
  }
}

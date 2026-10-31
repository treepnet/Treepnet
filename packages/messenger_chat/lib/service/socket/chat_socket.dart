part of messenger_chat;

/// Transport bilan UI o'rtasidagi ko'prik.
///
/// Ilgari bu yerda to'g'ridan-to'g'ri socket.io klienti turardi. Endi plagin
/// tarmoq haqida hech narsa bilmaydi: [ChatTransport.events] oqimini tinglaydi
/// va chiqadigan xabarlarni [ChatTransport.send] ga uzatadi.
///
/// Yuborilmagan xabar navbatga qo'yilmaydi: u o'z chatida "xato" holatida
/// qoladi va foydalanuvchi "Qayta yuborish" yoki "O'chirish"ni tanlaydi
/// (eski navbat nega olib tashlangani: [_removeLegacyOutbox]).
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
      // The status comes from the transport's own events: connect() returns
      // even when the socket couldn't connect, so marking it connected here
      // showed "connected" with no connection at all.
      await transport.connect();
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
          cubit.updateMessage(model);
        } else {
          cubit.addMessage(model);
        }

      case ChatMessageUpdated(:final message):
        // Tahrirlangan/o'chirilgan xabar - id/kalit bo'yicha topib almashtiramiz.
        cubit.updateMessage(
          _MessageModel.fromIncoming(
            message,
            myId: _ChatRuntime.instance.me.id,
          ),
        );

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

  /// Xabarni yuboradi. Xato bo'lsa [onError] chaqiriladi - xabar chatda
  /// "Qayta yuborish / O'chirish" bilan qoladi.
  static Future<void> send(
    ChatOutgoingMessage message, {
    void Function()? onSuccess,
    void Function(Object error)? onError,
  }) async {
    final transport = _transport;
    if (transport == null) {
      _ChatLogger.failure('⛔️ Transport ulanmagan, xabar yuborilmadi');
      onError?.call(StateError(_AppTexts.socketConnectionNot));
      return;
    }

    try {
      await transport.send(message);
      onSuccess?.call();
    } on ChatSendRejected catch (e) {
      _ChatLogger.failure('⛔️ Xabar rad etildi: ${e.reason}');
      onError?.call(e);
    } catch (e) {
      _ChatLogger.failure('⛔️ Xabar yuborilmadi: $e');
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

  static Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    try {
      await _transport?.editMessage(messageId: messageId, content: content);
    } catch (e) {
      _ChatLogger.print('editMessage yuborilmadi: $e');
    }
  }

  static Future<void> deleteMessage({required String messageId}) async {
    try {
      await _transport?.deleteMessage(messageId: messageId);
    } catch (e) {
      _ChatLogger.print('deleteMessage yuborilmadi: $e');
    }
  }
}

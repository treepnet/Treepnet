part of messenger_chat;

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this.chatRepository) : super(ChatState.initial);

  final _ChatRepository chatRepository;

  /// Most states here are emitted after an `await` (message fetches, typing
  /// timers). If the user left the chat in the meantime the cubit is already
  /// closed and `super.emit` throws "Cannot emit new states after calling
  /// close". Dropping the late emit is the right behaviour, so guard every
  /// emit in one place rather than at each call site.
  @override
  void emit(ChatState state) {
    if (isClosed) return;
    super.emit(state);
  }

  /// Ruxsat etilgan xabar turlarini o'qiydi.
  ///
  /// Tarmoqqa chiqmaydi - sozlama [MessengerChat.init] da berilgan
  /// [ChatFeatures] dan olinadi.
  void applyFeatures() {
    emit(
      state.copyWith(
        config: _ChatRuntime.instance.features._config,
        isLoading: false,
      ),
    );
  }

  Future<void> getMessages({bool isRefresh = false, int page = 1}) async {
    if (!state.messages.hasNextPage || state.isLoading || state.isLoadMore)
      return;
    if (isRefresh) {
      emit(state.copyWith(isLoading: true));
    } else {
      emit(state.copyWith(isLoadMore: true));
    }

    await _loadPage(page: page, isRefresh: isRefresh, retryOnce: page == 1);
  }

  /// The first page failed and was retried once, and failed again: the list
  /// shows the error with "Retry" ([reloadMessages]).
  Future<void> reloadMessages() async {
    emit(state.copyWith(failure: ''));
    await getMessages(isRefresh: true);
  }

  Future<void> _loadPage({
    required int page,
    required bool isRefresh,
    required bool retryOnce,
  }) async {
    final getMessageUseCase = _GetMessageUseCase(
      chatRepository: chatRepository,
    );

    final response = await getMessageUseCase.call(
      _ParamsGetMessage(page: page, size: 25),
    );

    response.either(
      (failure) async {
        if (failure.message == 'timeout') {
          _ChatLogger.warning('Messages loading timed out');
        }
        // A bad connection often recovers in a moment: the first page tries
        // once more by itself (still loading) before the error shows.
        if (retryOnce) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (!isClosed) {
            await _loadPage(page: page, isRefresh: isRefresh, retryOnce: false);
          }
          return;
        }
        emit(
          state.copyWith(
            failure: failure.message.toString(),
            isLoadMore: false,
            isLoading: false,
          ),
        );
      },
      (response) async {
        try {
          _ChatLogger.print(
            '📊 Received total ${response.messages.length} messages from API',
          );
          final existingIds = state.messages.messages.map((m) => m.id).toSet();
          final shouldAddList = List<_MessageModel>.empty(growable: true);

          for (final message in response.messages) {
            if (!existingIds.contains(message.id)) {
              existingIds.add(message.id);
              shouldAddList.add(message);
            }
          }
          _ChatLogger.print(
            '➕ Adding ${shouldAddList.length} new unique messages to state',
          );

          final combinedMessages = isRefresh
              ? response.messages
              : [...state.messages.messages, ...shouldAddList];

          emit(
            state.copyWith(
              messages: _MessageResponse(
                messages: combinedMessages,
                currentPage: response.currentPage,
                totalPage: response.totalPage,
                hasNextPage: response.hasNextPage,
                hasPreviousPage: response.hasPreviousPage,
                totalItems: response.totalItems,
              ),
              isLoadMore: false,
              isLoading: false,
              failure: '',
            ),
          );
        } catch (e, stack) {
          _ChatLogger.failure('Error processing messages in Cubit: $e\n$stack');
          emit(
            state.copyWith(
              isLoading: false,
              isLoadMore: false,
              failure: e.toString(),
            ),
          );
        }
      },
    );
  }

  Future<void> getMessagesWhenOnline() async {
    final getMessageUseCase = _GetMessageUseCase(
      chatRepository: chatRepository,
    );

    final response = await getMessageUseCase.call(
      const _ParamsGetMessage(page: 1, size: 25),
    );

    response.either(
      (failure) {
        if (failure.message == 'timeout') {
          _ChatLogger.warning('Online messages loading timed out');
        }
        emit(
          state.copyWith(
            failure: failure.message.toString(),
            isLoadMore: false,
            isLoading: false,
          ),
        );
      },
      (response) async {
        final current = [...state.messages.messages];
        final existingIds = current.map((m) => m.id).toSet();
        // Hali "yuborilmoqda" turgan nusxalar - kalit bo'yicha. Server o'sha
        // xabarni qaytarsa, nusxa almashtiriladi (aks holda ikki marta
        // chizilardi).
        final localByKey = <String, int>{
          for (final (index, message) in current.indexed)
            if (message.isLocal && message.key.isNotEmpty) message.key: index,
        };
        final shouldAddList = List<_MessageModel>.empty(growable: true);

        for (final message in response.messages) {
          final localIndex = message.key.isEmpty
              ? null
              : localByKey[message.key];
          if (localIndex != null) {
            current[localIndex] = message;
            existingIds.add(message.id);
            continue;
          }
          if (!existingIds.contains(message.id)) {
            existingIds.add(message.id);
            shouldAddList.add(message);
          }
        }

        final combinedMessages = [...shouldAddList, ...current];

        emit(
          state.copyWith(
            messages: state.messages.copyWith(messages: combinedMessages),
            isLoadMore: false,
            isLoading: false,
          ),
        );
      },
    );
  }

  Future<void> addMessage(_MessageModel message) async {
    // Lokal (hali serverga yetmagan) xabarlarning id si bo'sh bo'ladi, ya'ni
    // ular bir-biridan id bilan farq qilmaydi - faqat key bo'yicha
    // taqqoslaymiz.
    final existingIds = state.messages.messages
        .map((m) => m.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingKeys = state.messages.messages
        .map((m) => m.key)
        .where((k) => k.isNotEmpty)
        .toSet();

    if ((!message.isLocal && existingIds.contains(message.id)) ||
        (message.key.isNotEmpty && existingKeys.contains(message.key))) {
      _ChatLogger.print(
        '⚠️ Message already exists, skipping: ID=${message.id} / Key=${message.key}',
      );
      return;
    }
    _ChatLogger.print('📥 Cubit: Adding message ID=${message.id} to UI state');

    if (state.isBackgroundApp) {
      MessengerChat.notificationController.add(
        ChatModel(
          unreadMessageData: UnreadMessageData(
            content: message.contentType.isText
                ? message.content.content
                : message.contentType.name,
            isAnswer: message.isFromPeer,
            unreadCount: 0,
          ),
        ),
      );
    }

    MessengerChat.controller.update(
      ChatModel(
        unreadMessageData: UnreadMessageData(
          content: message.contentType.isText
              ? message.content.content
              : message.contentType.name,
          isAnswer: message.isFromPeer,
          unreadCount: 0,
        ),
      ),
    );
    final List<_MessageModel> newMessages = [
      message,
      ...state.messages.messages,
    ];
    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: newMessages),
        unreadCount: 0,
      ),
    );
    // Not while the app is in the background: nobody has seen it yet. It is
    // marked once the thread is back on screen (see `MessengerChat`).
    if (message.isFromPeer && !state.isBackgroundApp) {
      markAsRead();
    }
  }

  Timer? _readTimer;

  /// Marks the conversation read — once for a burst. Every unread message
  /// that scrolled into view, and every one that arrived, used to send its
  /// own signal (20 unread on opening = 20+ signals).
  void markAsRead() {
    _readTimer?.cancel();
    _readTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_ChatSocket.markRead()),
    );
  }

  @override
  Future<void> close() {
    // Leaving within the burst window: still send it.
    if (_readTimer?.isActive ?? false) unawaited(_ChatSocket.markRead());
    _readTimer?.cancel();
    _typingTimer?.cancel();
    return super.close();
  }

  /// Serverga yetmagan xabarni o'chiradi.
  void removeLocalMessage(String key) {
    emit(
      state.copyWith(
        messages: state.messages.copyWith(
          messages: state.messages.messages
              .where((m) => !(m.isLocal && m.key == key))
              .toList(),
        ),
      ),
    );
  }

  /// Yuborilmagan matnli xabarni o'sha kalit bilan qayta yuboradi - server
  /// bir kalitni bir marta saqlaydi, shuning uchun dublikat bo'lmaydi.
  Future<void> retryTextMessage(_MessageModel message) async {
    updateMessage(message.copyWith(status: MessageStatus.sending));
    await _ChatSocket.send(
      ChatOutgoingMessage(
        clientKey: message.key,
        kind: ChatMessageKind.text,
        content: message.content.content,
        replyTo: message.replyTo,
      ),
      onError: (_) =>
          updateMessage(message.copyWith(status: MessageStatus.error)),
    );
  }

  Future<void> updateMessage(_MessageModel message) async {
    bool matched = false;
    final updatedMessages = state.messages.messages.map((e) {
      if (message.key.isNotEmpty && e.key == message.key) {
        matched = true;
        if (e.isRead) {
          return message.copyWith(isRead: true, status: MessageStatus.seen);
        }
        return message;
      }
      return e;
    }).toList();

    // Lokal nusxa topilmasa (masalan ilova qayta ishga tushgan yoki boshqa
    // qurilmadan yuborilgan), xabarni yo'qotmasdan ro'yxatga qo'shamiz.
    //
    // Lekin avval serverdagi id bo'yicha tekshiramiz: aks holda kalit mos
    // kelmagan holatlarda bitta xabar ikki marta chiziladi va optimistik
    // nusxa "yuborilmoqda" holatida qotib qoladi.
    if (!matched && !message.isLocal) {
      final alreadyExists = updatedMessages.any(
        (e) => !e.isLocal && e.id == message.id,
      );
      if (!alreadyExists) {
        // Kalit bo'yicha topilmagan bo'lsa ham, hali serverga yetmagan
        // ayni turdagi optimistik xabarni almashtirishga urinamiz.
        final pendingIndex = updatedMessages.indexWhere(
          (e) =>
              e.isLocal &&
              e.isMine &&
              e.contentType == message.contentType &&
              e.status == MessageStatus.sending,
        );
        if (pendingIndex >= 0) {
          updatedMessages[pendingIndex] = message;
        } else {
          updatedMessages.insert(0, message);
        }
      }
    }

    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: updatedMessages),
        unreadCount: 0,
      ),
    );
  }

  Timer? _typingTimer;

  void typing({
    bool isTyping = true,
    String typingType = '',
    String? typingName,
  }) {
    _ChatLogger.print(
      '⌨️ Cubit: Updating isTyping to $isTyping, type: $typingType, name: $typingName',
    );
    emit(
      state.copyWith(
        isTyping: isTyping,
        typingType: typingType,
        typingName: typingName,
      ),
    );
    MessengerChat.controller.updateTyping(
      isTyping,
      typingType,
      userName: typingName,
    );

    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 4), () {
        _ChatLogger.print(
          '⌨️ Cubit: Typing timeout, resetting isTyping to false',
        );
        emit(state.copyWith(isTyping: false, typingType: '', typingName: null));
        MessengerChat.controller.updateTyping(false, '', userName: null);
      });
    }
  }

  void setIsBackgroundApp(value) {
    emit(state.copyWith(isBackgroundApp: value));
  }

  void markAllMessagesAsRead() {
    final updatedMessages = state.messages.messages.map((message) {
      final messageData = message.copyWith(
        isRead: true,
        status: MessageStatus.seen,
      );

      return messageData;
    }).toList();

    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: updatedMessages),
      ),
    );
  }

  void markMessageAsRead(dynamic id) {
    final updatedMessages = state.messages.messages.map((message) {
      if (message.id.toString() == id.toString()) {
        final messageData = message.copyWith(
          isRead: true,
          status: MessageStatus.seen,
        );
        return messageData;
      }

      return message;
    }).toList();

    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: updatedMessages),
      ),
    );
  }

  void resetState() {
    emit(ChatState.initial);
  }
}

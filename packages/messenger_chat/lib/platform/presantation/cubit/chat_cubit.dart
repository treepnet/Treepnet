part of messenger_chat;

class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this.chatRepository) : super(ChatState.initial);

  final _ChatRepository chatRepository;

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

    final getMessageUseCase = _GetMessageUseCase(
      chatRepository: chatRepository,
    );

    final response = await getMessageUseCase.call(
      _ParamsGetMessage(page: page, size: 25),
    );

    response.either(
      (failure) {
        if (failure.message == 'timeout') {
          _ChatLogger.warning('Messages loading timed out');
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
        final existingIds = state.messages.messages.map((m) => m.id).toSet();
        final shouldAddList = List<_MessageModel>.empty(growable: true);

        for (final message in response.messages) {
          if (!existingIds.contains(message.id)) {
            existingIds.add(message.id);
            shouldAddList.add(message);
          }
        }

        final combinedMessages = [...shouldAddList, ...state.messages.messages];

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

  void updateProgress(_MessageModel message) async {
    final updatedMessages = state.messages.messages.map((e) {
      if (e.key == message.key) {
        return message.copyWith(uploadProgress: message.uploadProgress);
      }
      return e;
    }).toList();

    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: updatedMessages),
      ),
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

    if (message.key.isNotEmpty) {
      final messageKeys = await _SecureStorage.getMessageKeyList();
      if (!messageKeys.contains(message.key)) {
        messageKeys.add(message.key);
        await _SecureStorage.setMessageKeyList(messageKeys);
      }
    }

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
    if (message.isFromPeer) {
      markAsRead();
    }
  }

  void markAsRead() {
    unawaited(_ChatSocket.markRead());
  }

  Future<void> updateMessage(_MessageModel message) async {
    final messageKeys = await _SecureStorage.getMessageKeyList();

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

    messageKeys.remove(message.key);

    emit(
      state.copyWith(
        messages: state.messages.copyWith(messages: updatedMessages),
        unreadCount: 0,
      ),
    );

    await _SecureStorage.setMessageKeyList(messageKeys);
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
    MessengerChat.controller.updateTyping(isTyping, typingType, userName: typingName);

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

  Future<void> sendFileMessage(
    String path,
    String fileSize, {
    required Function() downScrollCallback,
    required BuildContext context,
    Function()? success,
  }) async {
    final uploadMessageUseCase = _UploadMessageUseCase(
      repository: chatRepository,
    );

    final messageKey = DateTime.now().millisecondsSinceEpoch.toString();

    final contentType = _ContentType.fromPath(path);

    final Size size = switch (contentType) {
      (_ContentType.text) => const Size(0, 0),
      (_ContentType.voice) => const Size(0, 0),
      (_ContentType.video) => await _VideoSizeDetector.getFileVideoSize(
        context,
        path: path,
      ),
      (_ContentType.photo) => await _ImageSizeDetector.getFileImageSize(
        context,
        path: path,
      ),
      (_ContentType.document) => const Size(0, 0),
    };

    final messageData = _MessageModel.initial.copyWith(
      date: DateTime.now().toIso8601String(),
      uploadProgress: 0,
      status: MessageStatus.sending,
      key: messageKey,
      filePath: path,
      width: size.width,
      height: size.height,
      content: contentType.isDocument
          ? Message(content: path.split('/').last, size: fileSize)
          : null,
      contentType: contentType,
    );

    addMessage(messageData);
    downScrollCallback.call();

    final response = await uploadMessageUseCase.call(
      _UploadParams(
        path,
        messageKey,
        onSendProgress: (sent, total) {
          final progress = sent / total;
          final step = (progress * 10).floor() / 10;

          if (step > 0.0) {
            updateProgress(messageData.copyWith(uploadProgress: step));
          }
        },
      ),
    );

    response.either(
      (failure) {
        emit(state.copyWith(failure: failure.message.toString()));
        updateProgress(
          messageData.copyWith(uploadProgress: 0, status: MessageStatus.error),
        );

        if (failure.message == 'timeout') {
          _ChatLogger.warning('File upload timed out');
        } else {
          _ChatLogger.failure(failure.message.toString());
        }
      },
      (message) async {
        success?.call();
      },
    );
  }

  void resetState() {
    emit(ChatState.initial);
  }
}

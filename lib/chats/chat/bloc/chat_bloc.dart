import 'dart:async';
import 'dart:convert';

import 'package:chats_repository/chats_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

part 'chat_bloc.g.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required String chatId,
    required ChatsRepository chatsRepository,
    required String currentUserId,
  }) : _chatId = chatId,
       _chatsRepository = chatsRepository,
       _currentUserId = currentUserId,
       super(const ChatState.initial()) {
    on<ChatMessageChanged>(_onMessageChanged);
    on<ChatMessagesFetchRequested>(_onMessagesFetchRequested);
    on<ChatSendMessageRequested>(_onSendMessageRequested);
    on<ChatMessageDeleteRequested>(_onMessageDeleteRequested);
    on<ChatMessageSeen>(_onMessageSeen);
    on<ChatMarkReadRequested>(_onMarkReadRequested);
    on<ChatTypingRequested>(_onTypingRequested);
    on<ChatOtherReadAtChanged>(_onOtherReadAtChanged);
    on<ChatMessageEditRequested>(_onChatMessageEditRequested);

    _messagesRealtimeChannel = _chatsRepository.messagesUpdates(
      conversationId: _chatId,
      callback: _onMessageUpdated,
    );
    // The other participant's read watermark → ✓✓ on my messages.
    _readSub = _chatsRepository
        .otherReadAtOf(conversationId: _chatId, excludeUserId: _currentUserId)
        .listen((at) {
          if (!isClosed) add(ChatOtherReadAtChanged(at));
        });
  }

  StreamSubscription<void>? _messagesRealtimeChannel;
  StreamSubscription<DateTime?>? _readSub;
  final String _currentUserId;

  void _onOtherReadAtChanged(
    ChatOtherReadAtChanged event,
    Emitter<ChatState> emit,
  ) => emit(state.copyWith(otherReadAt: event.readAt));

  void _onMessageUpdated(
    ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord}) payload,
  ) => isClosed ? null : add(ChatMessageChanged(payload));

  final String _chatId;
  final ChatsRepository _chatsRepository;

  final _pageSize = 10;
  int _currentPage = 0;
  int _shiftOffset = 0;

  Future<List<Message>> _onData({
    required ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord})
    payload,
  }) async {
    final messages = [...state.messages];
    final data = payload.newRecord;
    final oldRecord = payload.oldRecord;
    assert(
      data.isNotEmpty || oldRecord.isNotEmpty,
      'Both data and oldRecord cannot be empty',
    );
    if (data.isEmpty && oldRecord.isNotEmpty) {
      final index = messages.indexWhere((msg) => msg.id == oldRecord['id']);
      if (index == -1) return messages;

      // Store the message before removing it to check for reply relationships
      final removedMessage = messages[index];
      messages.removeAt(index);
      _shiftOffset--;

      try {
        final hasReplyMessage = removedMessage.replyMessageId != null;
        if (hasReplyMessage) {
          final messageReplyId = removedMessage.replyMessageId;
          final replyMessages = messages
              .where((msg) => msg.id == messageReplyId)
              .toList();
          for (final message in replyMessages) {
            final messageIndex = messages.indexWhere(
              (msg) => msg.id == message.id,
            );
            if (messageIndex != -1) {
              messages[messageIndex] = messages[messageIndex].copyWith(
                repliedMessage: Message.empty,
                replyMessageId: '',
              );
            }
          }
        }
      } catch (_) {
        /// Safe to ignore error here. It can be thrown only if the message by
        /// [messageReplyId] is not found.
      }
      return messages;
    }
    Message message;
    if (data['shared_post_id'] == null || data['shared_post_media'] == null) {
      message = Message.fromRow(data);
    } else {
      final resultMedia =
          (jsonDecode(data['shared_post_media'] as String) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final media = resultMedia.map(Media.fromJson).toList();
      message = Message.fromRow(data, media: media);
    }
    final index = messages.indexWhere((msg) => msg.id == message.id);
    if (index != -1) {
      messages[index] = message;
    } else {
      messages.insert(0, message);
      _shiftOffset++;
    }
    return messages;
  }

  Future<void> _onMessageChanged(
    ChatMessageChanged event,
    Emitter<ChatState> emit,
  ) async {
    final messages = await _onData(payload: event.payload);
    emit(state.copyWith(messages: messages));

    // A new incoming message arrived while the chat is open. Re-mark the
    // conversation read so my "last read" watermark moves past it and the
    // sender sees ✓✓ immediately — without me having to leave and re-open the
    // chat (the open-time mark alone never covers messages that land later).
    final data = event.payload.newRecord;
    if (data.isNotEmpty &&
        data['from_id'] != _currentUserId &&
        !isClosed) {
      add(ChatMarkReadRequested(_currentUserId));
    }
  }

  Future<void> _onMessagesFetchRequested(
    ChatMessagesFetchRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      if (!state.hasMore) return;
      // final from = _pageSize * _currentPage;
      // final to = ((_currentPage * _pageSize) + _pageSize) - from + 1;
      final data = await _chatsRepository.getMessages(
        chatId: _chatId,
        limit: _pageSize,
        offset: (_pageSize * _currentPage) + _shiftOffset,
      );

      _currentPage++;

      // Drop any messages already in state (a realtime insert and a paginated
      // fetch can overlap) so no id appears twice — duplicate ValueKeys would
      // crash the list.
      final existingIds = state.messages.map((m) => m.id).toSet();
      final fresh = data.where((m) => !existingIds.contains(m.id)).toList();

      emit(
        state.copyWith(
          hasMore: data.length >= _pageSize,
          messages: [...state.messages, ...fresh],
          status: ChatStatus.success,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      // Surface the failure so an empty thread can show an error/retry state
      // instead of a permanently blank screen.
      emit(state.copyWith(status: ChatStatus.failure));
    }
  }

  Future<void> _onSendMessageRequested(
    ChatSendMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Optimistically show the message immediately so it appears without
    // waiting for the Supabase realtime echo (which has round-trip latency
    // and may not echo the sender's own insert). The realtime update later
    // dedupes by id in [_onData].
    final optimistic = event.message.copyWith(
      sender:
          event.message.sender ??
          PostAuthor.confirmed(
            id: event.sender.id,
            username: event.sender.username,
            avatarUrl: event.sender.avatarUrl,
          ),
    );
    // Clear any prior failure for this id (this may be a retry) so the bubble
    // drops its error mark while the send is back in flight.
    final clearedFailed = state.failedIds.contains(optimistic.id)
        ? (state.failedIds.where((id) => id != optimistic.id).toSet())
        : state.failedIds;

    if (state.messages.indexWhere((m) => m.id == optimistic.id) == -1) {
      _shiftOffset++;
      emit(
        state.copyWith(
          messages: [optimistic, ...state.messages],
          status: ChatStatus.success,
          failedIds: clearedFailed,
        ),
      );
    } else if (clearedFailed != state.failedIds) {
      emit(state.copyWith(failedIds: clearedFailed));
    }

    try {
      await _chatsRepository.sendMessage(
        chatId: _chatId,
        sender: event.sender,
        receiver: event.receiver,
        message: event.message,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      // Keep the bubble but flag it failed so the UI can warn + offer a retry;
      // the text is not lost.
      emit(
        state.copyWith(
          status: ChatStatus.failure,
          failedIds: {...state.failedIds, optimistic.id},
        ),
      );
    }
  }

  Future<void> _onMessageDeleteRequested(
    ChatMessageDeleteRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatsRepository.deleteMessage(messageId: event.messageId);
      emit(state.copyWith(status: ChatStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: ChatStatus.failure));
    }
  }

  Future<void> _onMessageSeen(
    ChatMessageSeen event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatsRepository.readMessage(messageId: event.messageId);
      emit(state.copyWith(status: ChatStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: ChatStatus.failure));
    }
  }

  Future<void> _onMarkReadRequested(
    ChatMarkReadRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatsRepository.markConversationRead(
        chatId: _chatId,
        userId: event.userId,
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onTypingRequested(
    ChatTypingRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatsRepository.setTyping(
        conversationId: _chatId,
        userId: event.userId,
      );
    } catch (_) {
      // Typing is best-effort; a failed heartbeat is not worth surfacing.
    }
  }

  Future<void> _onChatMessageEditRequested(
    ChatMessageEditRequested event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _chatsRepository.editMessage(
        oldMessage: event.oldMessage,
        newMessage: event.newMessage,
      );
      emit(state.copyWith(status: ChatStatus.success));
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(state.copyWith(status: ChatStatus.failure));
    }
  }

  @override
  Future<void> close() {
    unawaited(_messagesRealtimeChannel?.cancel());
    unawaited(_readSub?.cancel());
    return super.close();
  }
}

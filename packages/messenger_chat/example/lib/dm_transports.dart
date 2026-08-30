import 'dart:async';

import 'package:dio/dio.dart';
import 'package:messenger_chat/messenger_chat.dart';

import 'dm_api.dart';

/// Bitta suhbat uchun transport.
class DmChatTransport implements ChatTransport {
  DmChatTransport({
    required this.api,
    required this.conversationId,
    required this.myUserId,
  });

  final DmApi api;
  final String conversationId;

  /// Serverdagi son ko'rinishidagi identifikator (`senderId` bilan
  /// solishtiriladi).
  final String myUserId;

  StreamSubscription<DmEvent>? _subscription;
  final _events = StreamController<ChatTransportEvent>.broadcast();

  @override
  Stream<ChatTransportEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _subscription ??= api.events.listen((event) {
      switch (event) {
        case DmMessageEvent(:final message):
          // Faqat shu suhbatga tegishli xabarlar.
          if (message.conversationId != conversationId) return;
          _events.add(ChatMessageReceived(_toIncoming(message)));

        case DmTypingEvent(:final isTyping, :final contentType)
            when event.conversationId == conversationId:
          _events.add(
            ChatTypingChanged(
              userId: '',
              isTyping: isTyping,
              kind: switch (contentType) {
                'voice' => ChatMessageKind.voice,
                'photo' => ChatMessageKind.photo,
                'video' => ChatMessageKind.video,
                'document' => ChatMessageKind.file,
                _ => null,
              },
            ),
          );

        case DmReadEvent(:final messageId, :final all)
            when event.conversationId == conversationId:
          _events.add(ChatMessagesRead(messageId: messageId, all: all));

        // 1:1 suhbatda o'zimizdan boshqa har kim - suhbatdosh.
        case DmPresenceEvent(:final userId, :final isOnline, :final lastSeen)
            when userId != myUserId:
          _events.add(
            ChatPeerPresence(
              userId: userId,
              isOnline: isOnline,
              lastSeen: lastSeen,
            ),
          );

        case DmConnectionEvent(:final status):
          _events.add(ChatConnectionChanged(status));

        default:
          break;
      }
    });

    await api.connect();
  }

  @override
  Future<ChatHistoryPage> loadHistory({
    required int page,
    required int size,
  }) async {
    final response = await api.dio.get<Map<String, dynamic>>(
      '/chat/dm/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'size': size},
    );

    final items = (response.data?['data'] as List?) ?? const [];
    return ChatHistoryPage(
      messages: items
          .whereType<Map>()
          .map(DmMessage.fromJson)
          .map(_toIncoming)
          .toList(growable: false),
      hasMore: response.data?['hasMore'] == true,
    );
  }

  @override
  Future<void> send(ChatOutgoingMessage message) async => api.send(
    conversationId: conversationId,
    content: message.content,
    contentType: dmContentTypeOf(message.kind),
    key: message.clientKey,
    duration: message.duration,
    size: message.size,
  );

  @override
  Future<ChatUploadResult> uploadAttachment({
    required String filePath,
    required String clientKey,
    required ChatMessageKind kind,
    void Function(int sent, int total)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'contentType': dmContentTypeOf(kind),
    });

    // Messenger uchun alohida endpoint: faqat faylni saqlaydi va manzilini
    // qaytaradi, hech qanday xabar yaratmaydi.
    final response = await api.dio.post<Map<String, dynamic>>(
      '/chat/dm/upload',
      data: formData,
      onSendProgress: onProgress,
    );

    final body = response.data ?? const {};
    final url = api.absolute(body['url']?.toString() ?? '');
    final waveform = api.absolute(body['svg']?.toString() ?? '');
    // Video uchun server thumbnail hosil qiladi (`png`).
    final thumbnail = api.absolute(body['png']?.toString() ?? '');

    // Yuklangandan keyin xabarni o'zimiz yuboramiz.
    api.send(
      conversationId: conversationId,
      content: url,
      contentType: dmContentTypeOf(kind),
      key: clientKey,
      svg: body['svg']?.toString(),
      png: body['png']?.toString(),
      duration: body['duration']?.toString(),
      size: body['size']?.toString(),
    );

    return ChatUploadResult(
      url: url,
      waveformUrl: waveform,
      thumbnailUrl: thumbnail,
      duration: body['duration']?.toString(),
      size: body['size']?.toString(),
    );
  }

  @override
  Future<void> sendTyping({
    required bool isTyping,
    ChatMessageKind? kind,
  }) async => api.typing(
    conversationId: conversationId,
    isTyping: isTyping,
    contentType: kind == null ? null : dmContentTypeOf(kind),
  );

  @override
  Future<void> markRead({String? messageId}) async =>
      api.markRead(conversationId: conversationId, messageId: messageId);

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _events.close();
    // `api` ni yopmaymiz - u ro'yxat ekraniga tegishli.
  }

  ChatIncomingMessage _toIncoming(DmMessage m) => ChatIncomingMessage(
    id: m.id,
    senderId: m.senderId,
    kind: m.kind,
    content: m.kind == ChatMessageKind.text
        ? m.content
        : api.absolute(m.content),
    waveformUrl: api.absolute(m.svg ?? ''),
    thumbnailUrl: api.absolute(m.png ?? ''),
    duration: m.duration,
    size: m.size,
    sentAt: m.date,
    clientKey: m.key,
    isRead: m.isRead,
  );
}

/// Suhbatlar ro'yxati uchun transport.
class DmListTransport implements ChatListTransport {
  DmListTransport({required this.api, required this.myUserId});

  final DmApi api;
  final String myUserId;

  StreamSubscription<DmEvent>? _subscription;
  final _events = StreamController<ChatListEvent>.broadcast();

  /// Ro'yxatning joriy holati - hodisa kelganda shu asosda yangilaymiz.
  final Map<String, ChatConversation> _conversations = {};

  @override
  Stream<ChatListEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _subscription ??= api.events.listen((event) {
      switch (event) {
        case DmMessageEvent(:final message):
          final current = _conversations[message.conversationId];
          if (current == null) {
            // Yangi suhbat - ro'yxatni qayta yuklash kerak.
            unawaited(_refreshOne(message.conversationId));
            return;
          }
          final isMine = message.senderId == myUserId;
          final updated = current.copyWith(
            lastMessage: message.kind == ChatMessageKind.text
                ? message.content
                : '',
            lastMessageKind: message.kind,
            lastMessageAt: message.date,
            lastMessageIsMine: isMine,
            lastMessageIsRead: false,
            unreadCount: isMine
                ? current.unreadCount
                : current.unreadCount + 1,
          );
          _conversations[updated.id] = updated;
          _events.add(ChatConversationUpserted(updated));

        case DmReadEvent(:final conversationId):
          final current = _conversations[conversationId];
          if (current == null) return;
          final updated = current.copyWith(
            unreadCount: 0,
            lastMessageIsRead: true,
          );
          _conversations[conversationId] = updated;
          _events.add(ChatConversationUpserted(updated));

        case DmPresenceEvent(:final userId, :final isOnline, :final lastSeen):
          _events.add(
            ChatPeerPresenceChanged(
              peerId: userId,
              isOnline: isOnline,
              lastSeen: lastSeen,
            ),
          );

        case DmConnectionEvent(:final status):
          _events.add(ChatListConnectionChanged(status));

        default:
          break;
      }
    });

    await api.connect();
  }

  @override
  Future<ChatConversationPage> loadConversations({
    required int page,
    required int size,
  }) async {
    final response = await api.dio.get<Map<String, dynamic>>(
      '/chat/dm/conversations',
      queryParameters: {'page': page, 'size': size},
    );

    final items = (response.data?['data'] as List?) ?? const [];
    final conversations = items
        .whereType<Map>()
        .map(_toConversation)
        .toList(growable: false);

    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }

    return ChatConversationPage(
      conversations: conversations,
      hasMore: response.data?['hasMore'] == true,
    );
  }

  Future<void> _refreshOne(String conversationId) async {
    try {
      final page = await loadConversations(page: 1, size: 30);
      for (final conversation in page.conversations) {
        _events.add(ChatConversationUpserted(conversation));
      }
    } catch (_) {
      // Ro'yxatni yangilay olmasak, keyingi hodisada qayta urinamiz.
    }
  }

  ChatConversation _toConversation(Map<dynamic, dynamic> json) {
    final peer = json['peer'] as Map?;
    final last = json['lastMessage'] as Map?;
    final message = last == null ? null : DmMessage.fromJson(last);

    return ChatConversation(
      id: json['id']?.toString() ?? '',
      peer: ChatUser(
        id: peer?['id']?.toString() ?? '',
        name: peer?['name']?.toString() ?? '',
        avatarUrl: peer?['avatar']?.toString(),
      ),
      lastMessage: message?.kind == ChatMessageKind.text
          ? (message?.content ?? '')
          : '',
      lastMessageKind: message?.kind ?? ChatMessageKind.text,
      lastMessageAt:
          DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ??
          message?.date,
      lastMessageIsMine: message?.senderId == myUserId,
      lastMessageIsRead: message?.isRead ?? false,
      unreadCount: (json['unreadCount'] as int?) ?? 0,
    );
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _events.close();
    await api.dispose();
  }
}

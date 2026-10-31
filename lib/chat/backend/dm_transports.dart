import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:messenger_chat/messenger_chat.dart';

import 'package:treepnet/chat/backend/dm_api.dart';
import 'package:treepnet/chat/chat_share_ref.dart';

/// Inbox last-message preview text. Renders a share sentinel as a friendly
/// label instead of the raw `treepnet:share:...` string.
String _previewText(String content) => switch (parseSharedRef(content)?.kind) {
  SharedRefKind.post => '📷 Post',
  SharedRefKind.story => '📖 Story',
  _ => content,
};

/// Transport for a single conversation.
///
/// Adapted verbatim from the messenger_chat plugin example
/// (`example/lib/dm_transports.dart`).
class DmChatTransport implements ChatTransport {
  DmChatTransport({
    required this.api,
    required this.conversationId,
    required this.myUserId,
  });

  final DmApi api;
  final String conversationId;

  /// Our server-side (numeric) id — compared against `senderId`.
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
          // Only messages belonging to this conversation.
          if (message.conversationId != conversationId) return;
          _events.add(ChatMessageReceived(_toIncoming(message)));

        case DmMessageUpdatedEvent(:final message)
            when message.conversationId == conversationId:
          _events.add(ChatMessageUpdated(_toIncoming(message)));

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

        // The peer read our messages: ✓✓. Our own read comes back too (the
        // backend tells both sides) and used to tick every message we'd sent.
        case DmReadEvent(:final messageId, :final all, :final readerId)
            when event.conversationId == conversationId &&
                readerId != myUserId:
          _events.add(ChatMessagesRead(messageId: messageId, all: all));

        // In a 1:1 conversation, anyone who isn't us is the peer.
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
    // connect() also returns when the socket couldn't connect, and a socket
    // the inbox already opened sends no new event: report where it stands.
    _events.add(ChatConnectionChanged(api.status));
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
          .whereType<Map<dynamic, dynamic>>()
          .map(DmMessage.fromJson)
          .map(_toIncoming)
          .toList(growable: false),
      hasMore: response.data?['hasMore'] == true,
    );
  }

  @override
  Future<void> send(ChatOutgoingMessage message) async => _confirm(
    await api.send(
      conversationId: conversationId,
      content: message.content,
      contentType: dmContentTypeOf(message.kind),
      key: message.clientKey,
      duration: message.duration,
      size: message.size,
      replyToId: message.replyTo?.messageId,
      replyToContent: message.replyTo?.content,
      replyToSenderId: message.replyTo?.senderId,
    ),
  );

  /// Turns the backend's answer into what the chat plugin expects: nothing on
  /// success, [ChatSendRejected] when it refused the message for good (not
  /// queued again), any other error when it's worth resending later.
  void _confirm(DmSendResult result) {
    if (result.ok) return;
    if (result.isRejected) throw ChatSendRejected(result.code ?? result.error!);
    throw StateError('Message not confirmed: ${result.error}');
  }

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

    // Dedicated endpoint: stores the file and returns its URL, without
    // creating a message.
    final response = await api.dio.post<Map<String, dynamic>>(
      '/chat/dm/upload',
      data: formData,
      onSendProgress: onProgress,
      // A video takes a while to send and store; on some adapters this limit
      // also covers sending.
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );

    final body = response.data ?? const {};
    final url = api.absolute(body['url']?.toString() ?? '');
    final waveform = api.absolute(body['svg']?.toString() ?? '');
    // The server generates a thumbnail (`png`) for video.
    final thumbnail = api.absolute(body['png']?.toString() ?? '');

    // Send the message ourselves once the upload finishes; a failure shows
    // on the message (with Retry) like a failed upload.
    _confirm(
      await api.send(
        conversationId: conversationId,
        content: url,
        contentType: dmContentTypeOf(kind),
        key: clientKey,
        svg: body['svg']?.toString(),
        png: body['png']?.toString(),
        duration: body['duration']?.toString(),
        size: body['size']?.toString(),
      ),
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
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async => _confirmChange(
    await api.edit(messageId: messageId, content: content),
  );

  @override
  Future<void> deleteMessage({required String messageId}) async =>
      _confirmChange(await api.deleteMessage(messageId: messageId));

  /// The plugin learns of a refused or lost edit / delete from the throw.
  static void _confirmChange(DmSendResult result) {
    if (!result.ok) throw StateError(result.error ?? 'not confirmed');
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _events.close();
    // We don't close `api` — it belongs to the inbox screen.
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
    isEdited: m.isEdited,
    isDeleted: m.isDeleted,
    replyTo: m.replyToId == null
        ? null
        : ChatReplyInfo(
            messageId: m.replyToId!,
            content: m.replyToContent ?? '',
            senderId: m.replyToSenderId ?? '',
          ),
  );
}

/// Transport for the conversation list (inbox).
class DmListTransport implements ChatListTransport {
  DmListTransport({required this.api, required this.myUserId});

  final DmApi api;
  final String myUserId;

  StreamSubscription<DmEvent>? _subscription;
  final _events = StreamController<ChatListEvent>.broadcast();

  /// The list's current state — we update it from incoming events.
  final Map<String, ChatConversation> _conversations = {};

  /// Peer's app-side profile uuid per conversation id. The plugin's [ChatUser]
  /// only carries the backend numeric id, but block checks need the app uuid —
  /// so we keep it here from the conversation payload.
  final Map<String, String> _peerUuidById = {};

  /// The app-side profile uuid of the conversation's peer, if known.
  String? peerUuidOf(String conversationId) => _peerUuidById[conversationId];

  /// The loaded conversation with the person whose app-side uuid is
  /// [peerUuid], if the list has it — opening their chat from a profile then
  /// skips the find-or-create round trip.
  ChatConversation? conversationWithPeer(String peerUuid) {
    for (final entry in _peerUuidById.entries) {
      if (entry.value == peerUuid) return _conversations[entry.key];
    }
    return null;
  }

  /// App-side uuids of peers we've actually EXCHANGED A MESSAGE with (the
  /// conversation has a last message). Used to hide them from the "new chat"
  /// (Type) recommendations — an empty, just-opened conversation keeps the
  /// person in Type until something is written.
  Set<String> get messagedPeerUuids {
    final result = <String>{};
    for (final c in _conversations.values) {
      // Any message — a photo or a deleted one has no preview text.
      if (c.lastMessageId != null) {
        final uuid = _peerUuidById[c.id];
        if (uuid != null) result.add(uuid);
      }
    }
    return result;
  }

  /// Total unread across all conversations, for the nav-bar badge. Updated
  /// whenever [_conversations] changes.
  final ValueNotifier<int> unreadTotal = ValueNotifier<int>(0);

  /// [refresh] runs at most this often, so a flaky connection or quick app
  /// switches don't pile up requests.
  static const _refreshGap = Duration(seconds: 30);
  DateTime? _lastRefresh;
  bool _refreshing = false;

  /// The socket dropped since it last connected; reload once it's back.
  bool _wasDisconnected = false;

  /// Reloads the first page of the list. Messages and new conversations that
  /// arrived while the socket was down (or the app was in the background)
  /// only reach the list — and the unread badge — this way. At most once per
  /// [_refreshGap], and never two at once.
  Future<void> refresh() async {
    final last = _lastRefresh;
    if (_refreshing ||
        (last != null && DateTime.now().difference(last) < _refreshGap)) {
      return;
    }
    _refreshing = true;
    _lastRefresh = DateTime.now();
    try {
      final page = await loadConversations(page: 1, size: 30);
      for (final conversation in page.conversations) {
        _events.add(ChatConversationUpserted(conversation));
      }
    } catch (_) {
      // The next reconnect or return to the app tries again.
    } finally {
      _refreshing = false;
    }
  }

  void _recomputeUnread() {
    unreadTotal.value = _conversations.values.fold<int>(
      0,
      (sum, c) => sum + c.unreadCount,
    );
  }

  @override
  Stream<ChatListEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    _subscription ??= api.events.listen((event) {
      switch (event) {
        case DmMessageEvent(:final message):
          final current = _conversations[message.conversationId];
          if (current == null) {
            // New conversation — reload the list.
            unawaited(_refreshOne(message.conversationId));
            return;
          }
          final isMine = message.senderId == myUserId;
          final updated = current.copyWith(
            lastMessage: message.kind == ChatMessageKind.text
                ? _previewText(message.content)
                : '',
            lastMessageKind: message.kind,
            lastMessageId: message.id,
            lastMessageDeleted: false,
            lastMessageAt: message.date,
            lastMessageIsMine: isMine,
            lastMessageIsRead: false,
            unreadCount: isMine
                ? current.unreadCount
                : current.unreadCount + 1,
          );
          _conversations[updated.id] = updated;
          _recomputeUnread();
          _events.add(ChatConversationUpserted(updated));

        // An edited or deleted message: if it's the one the list shows, the
        // preview follows — a deleted text must not stay readable here.
        case DmMessageUpdatedEvent(:final message):
          final current = _conversations[message.conversationId];
          if (current == null || current.lastMessageId != message.id) return;
          final isText = message.kind == ChatMessageKind.text;
          final updated = current.copyWith(
            lastMessage: message.isDeleted || !isText
                ? ''
                : _previewText(message.content),
            lastMessageDeleted: message.isDeleted,
          );
          _conversations[updated.id] = updated;
          _events.add(ChatConversationUpserted(updated));

        case DmReadEvent(:final conversationId, :final readerId):
          final current = _conversations[conversationId];
          if (current == null) return;
          // We read it: nothing unread left. The peer read it: only our last
          // message gets its ✓✓ — what we haven't read stays unread.
          final weRead = readerId == myUserId;
          final updated = current.copyWith(
            unreadCount: weRead ? 0 : current.unreadCount,
            lastMessageIsRead: weRead
                ? !current.lastMessageIsMine || current.lastMessageIsRead
                : current.lastMessageIsMine || current.lastMessageIsRead,
          );
          _conversations[conversationId] = updated;
          _recomputeUnread();
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
          if (status == ChatConnectionStatus.connected) {
            if (_wasDisconnected) unawaited(refresh());
            _wasDisconnected = false;
          } else {
            _wasDisconnected = true;
          }

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
        .whereType<Map<dynamic, dynamic>>()
        .map(_toConversation)
        .toList(growable: false);

    for (final conversation in conversations) {
      _conversations[conversation.id] = conversation;
    }
    _recomputeUnread();

    return ChatConversationPage(
      conversations: conversations,
      hasMore: response.data?['hasMore'] == true,
    );
  }

  /// Deletes a conversation on the backend and drops it from the inbox.
  Future<void> deleteConversation(String conversationId) async {
    await api.dio.delete<void>('/chat/dm/conversations/$conversationId');
    _conversations.remove(conversationId);
    _peerUuidById.remove(conversationId);
    _recomputeUnread();
    _events.add(ChatConversationRemoved(conversationId));
  }

  Future<void> _refreshOne(String conversationId) async {
    try {
      final page = await loadConversations(page: 1, size: 30);
      for (final conversation in page.conversations) {
        _events.add(ChatConversationUpserted(conversation));
      }
    } catch (_) {
      // If the refresh fails, we retry on the next event.
    }
  }

  ChatConversation _toConversation(Map<dynamic, dynamic> json) {
    final peer = json['peer'] as Map?;
    final last = json['lastMessage'] as Map?;
    final message = last == null ? null : DmMessage.fromJson(last);

    final id = json['id']?.toString() ?? '';
    final peerUuid = peer?['uuid']?.toString();
    if (peerUuid != null && peerUuid.isNotEmpty) {
      _peerUuidById[id] = peerUuid;
    }

    return ChatConversation(
      id: id,
      peer: ChatUser(
        id: peer?['id']?.toString() ?? '',
        name: peer?['name']?.toString() ?? '',
        avatarUrl: peer?['avatar']?.toString(),
        // Seed live status from REST so opening from the inbox shows the peer's
        // current online state immediately, not just after a presence event.
        isOnline: peer?['isOnline'] == true,
        lastSeen: DateTime.tryParse(peer?['lastSeen']?.toString() ?? ''),
      ),
      lastMessage: message != null &&
              !message.isDeleted &&
              message.kind == ChatMessageKind.text
          ? _previewText(message.content)
          : '',
      lastMessageKind: message?.kind ?? ChatMessageKind.text,
      lastMessageId: message?.id,
      lastMessageDeleted: message?.isDeleted ?? false,
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
    unreadTotal.dispose();
    await _events.close();
    // `api` belongs to ChatSession, which closes it.
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Shared transport layer for the chat backend: one HTTP client and one socket.
///
/// The inbox (conversation list) and an open conversation reuse the SAME socket,
/// so the list keeps updating in real time even while a chat is open.
///
/// Adapted verbatim from the messenger_chat plugin example
/// (`example/lib/dm_api.dart`); only the library wiring differs.
class DmApi {
  DmApi({
    required this.baseUrl,
    required this.myUuid,
    required this.appName,
    required this.apiKey,
    required this.deviceId,
    required this.deviceName,
    required this.idToken,
    this.lang = 'en',
    this.userName,
    this.userAvatar,
  });

  final String baseUrl;
  final String myUuid;
  final String appName;
  final String apiKey;
  final String deviceId;
  final String deviceName;

  /// The signed-in user's Firebase ID token, sent with every request and every
  /// socket (re)connect so the backend identifies us from the token instead of
  /// trusting `x-uuid`. Null when no token is at hand; the backend then falls
  /// back to `x-uuid` for as long as it still accepts old app versions.
  final Future<String?> Function({bool forceRefresh}) idToken;

  /// App language ('en' / 'ru'): the backend words this user's chat push
  /// notifications in it. See [setLanguage].
  String lang;

  /// Display name and avatar of the current user. Sent as `x-name` / `x-avatar`
  /// so the backend can populate this user's row — otherwise the peer would see
  /// only a device name. Written server-side only when non-empty.
  ///
  /// Mutable because the very first `ensureStarted` (from the nav bar, at
  /// startup) can fire before the profile's username has synced into AppBloc,
  /// sending `x-name: Unknown`; [refreshIdentity] updates it once the real
  /// username is known so the peer stops seeing "Unknown".
  String? userName;
  String? userAvatar;

  /// Bounded, so a bad connection fails in seconds (and the screen can say
  /// so) instead of loading for minutes. Uploads get a longer wait for the
  /// answer (see DmChatTransport.uploadAttachment).
  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      headers: _headers,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  )
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _token();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        // A token can expire between fetching and the server checking it:
        // refresh once and retry before giving up.
        onError: (e, handler) async {
          final options = e.requestOptions;
          if (e.response?.statusCode != 401 ||
              options.extra['authRetried'] == true) {
            return handler.next(e);
          }
          final token = await _token(forceRefresh: true);
          if (token == null) return handler.next(e);
          options.extra['authRetried'] = true;
          options.headers['Authorization'] = 'Bearer $token';
          final data = options.data;
          if (data is FormData) options.data = data.clone();
          try {
            handler.resolve(await dio.fetch<dynamic>(options));
          } on DioException catch (retryError) {
            handler.next(retryError);
          }
        },
      ),
    );

  io.Socket? _socket;
  final _events = StreamController<DmEvent>.broadcast();
  Completer<void>? _connecting;

  /// Set when the backend refused our socket token: the next connect fetches a
  /// fresh one instead of the cached token.
  bool _refreshTokenOnConnect = false;

  /// Reconnects after the backend refused our token. A socket the server
  /// disconnected does not reconnect on its own.
  Timer? _authRetryTimer;
  int _authRetries = 0;

  /// The socket was closed on purpose while the app is in the background
  /// ([pause]); [resume] opens it again.
  bool _paused = false;

  /// Closes the socket while the app is in the background, so the backend
  /// treats us as offline and sends new messages as push notifications.
  void pause() {
    final socket = _socket;
    if (socket == null || _paused) return;
    _paused = true;
    _authRetryTimer?.cancel();
    socket.disconnect();
  }

  /// Opens the socket again after [pause].
  void resume() {
    if (!_paused) return;
    _paused = false;
    final socket = _socket;
    if (socket != null && socket.disconnected) {
      _status = ChatConnectionStatus.connecting;
      socket.connect();
    }
  }

  /// [idToken], never throwing: a failed token fetch must not break the chat.
  Future<String?> _token({bool forceRefresh = false}) async {
    try {
      return await idToken(forceRefresh: forceRefresh);
    } catch (_) {
      return null;
    }
  }

  void _retryAfterAuthError() {
    _refreshTokenOnConnect = true;
    // A few spaced tries (2 s, 4 s, 8 s); after that the next [connect] call —
    // opening the inbox or a thread — tries again.
    if (_authRetries >= 3) return;
    final delay = Duration(seconds: 2 << _authRetries);
    _authRetries++;
    _authRetryTimer?.cancel();
    _authRetryTimer = Timer(delay, () {
      final socket = _socket;
      if (socket != null && socket.disconnected) socket.connect();
    });
  }

  /// Updates the current user's name/avatar mid-session and re-announces it to
  /// the backend (which upserts the row on the next authenticated request).
  /// No-op when nothing meaningfully improves — a blank or "Unknown" name never
  /// overwrites a real one.
  void refreshIdentity({String? name, String? avatar}) {
    var changed = false;
    if (name != null &&
        name.isNotEmpty &&
        name != 'Unknown' &&
        name != userName) {
      userName = name;
      dio.options.headers['x-name'] = name;
      changed = true;
    }
    if (avatar != null && avatar.isNotEmpty && avatar != userAvatar) {
      userAvatar = avatar;
      dio.options.headers['x-avatar'] = avatar;
      changed = true;
    }
    if (!changed) return;
    // Touch an authenticated endpoint so the backend re-upserts our row with
    // the corrected name. Best-effort — the next real request would carry it
    // anyway now that the header is updated.
    unawaited(
      dio
          .get<Map<String, dynamic>>('/chat/dm/me')
          .catchError(
            (_) => Response<Map<String, dynamic>>(
              requestOptions: RequestOptions(path: '/chat/dm/me'),
            ),
          ),
    );
  }

  Map<String, String> get _headers => {
    'x-uuid': myUuid,
    'x-app': appName,
    'x-app-key': apiKey,
    'x-device-id': deviceId,
    'x-device-name': deviceName,
    'x-device-type': 'mobile',
    'x-lang': lang,
    if (userName != null && userName!.isNotEmpty) 'x-name': userName!,
    if (userAvatar != null && userAvatar!.isNotEmpty) 'x-avatar': userAvatar!,
  };

  Stream<DmEvent> get events => _events.stream;

  /// Connects the socket once; repeated calls await the same connection.
  /// Where the socket stands right now, kept from its own events.
  ChatConnectionStatus get status => _status;
  ChatConnectionStatus _status = ChatConnectionStatus.disconnected;

  Future<void> connect() {
    final existing = _connecting;
    if (existing != null) {
      // Already connected once. If the socket has since dropped (app was
      // backgrounded / went idle), nudge a reconnect so reopening a thread or
      // the inbox brings it back — socket.io keeps retrying on its own, this
      // just hastens it.
      final current = _socket;
      if (current != null && current.disconnected) {
        _paused = false;
        _status = ChatConnectionStatus.connecting;
        current.connect();
      }
      return existing.future;
    }

    final completer = Completer<void>();
    _connecting = completer;

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(_headers)
          // Called on every (re)connect, so a reconnect an hour later carries a
          // fresh token rather than the expired one from the first connect.
          .setAuthFn((callback) {
            final force = _refreshTokenOnConnect;
            _refreshTokenOnConnect = false;
            _token(
              forceRefresh: force,
            ).then((token) => callback(token == null ? {} : {'token': token}));
          })
          // Offline, retries back off from 1 s up to 30 s instead of every
          // 1–5 s forever.
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _authRetries = 0;
      _status = ChatConnectionStatus.connected;
      _events.add(const DmConnectionEvent(ChatConnectionStatus.connected));
      if (!completer.isCompleted) completer.complete();
    });
    socket.onDisconnect((_) {
      _status = ChatConnectionStatus.disconnected;
      _events.add(const DmConnectionEvent(ChatConnectionStatus.disconnected));
    });
    socket.onConnectError((e) {
      _status = ChatConnectionStatus.error;
      _events.add(const DmConnectionEvent(ChatConnectionStatus.error));
      if (!completer.isCompleted) completer.complete();
    });

    // The backend refused our token (expired, or not yet refreshed) and is
    // about to disconnect us.
    socket.on('dm.authError', (_) => _retryAfterAuthError());

    socket.on('dm.newMessage', (data) {
      if (data is Map) _events.add(DmMessageEvent(DmMessage.fromJson(data)));
    });
    void onUpdated(dynamic data) {
      if (data is Map) {
        _events.add(DmMessageUpdatedEvent(DmMessage.fromJson(data)));
      }
    }

    socket.on('dm.messageEdited', onUpdated);
    socket.on('dm.messageDeleted', onUpdated);
    socket.on('dm.typing', (data) {
      if (data is! Map) return;
      _events.add(
        DmTypingEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          isTyping: data['isTyping'] != false,
          contentType: data['contentType']?.toString(),
        ),
      );
    });
    socket.on('dm.presence', (data) {
      if (data is! Map) return;
      _events.add(
        DmPresenceEvent(
          userId: data['userId']?.toString() ?? '',
          isOnline: data['isOnline'] == true,
          lastSeen: DateTime.tryParse(data['lastSeen']?.toString() ?? ''),
        ),
      );
    });

    socket.on('dm.read', (data) {
      if (data is! Map) return;
      _events.add(
        DmReadEvent(
          conversationId: data['conversationId']?.toString() ?? '',
          messageId: data['messageId']?.toString(),
          all: data['all'] == true,
        ),
      );
    });

    _socket = socket;
    _status = ChatConnectionStatus.connecting;
    socket.connect();
    return completer.future;
  }

  /// How long [send] waits for the backend to confirm a message.
  static const _sendTimeout = Duration(seconds: 15);

  /// Sends a message and waits (up to [_sendTimeout]) for the backend to
  /// confirm it. The backend stores a [key] once, so sending the same message
  /// again never duplicates it.
  Future<DmSendResult> send({
    required String conversationId,
    required String content,
    required String contentType,
    required String key,
    String? svg,
    String? png,
    String? duration,
    String? size,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderId,
  }) {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Socket mavjud emas');
    }
    // Don't drop the message when the socket is momentarily disconnected
    // (backgrounded / idle / mid-reconnect): socket.io buffers emits made while
    // disconnected and flushes them on reconnect, so the message still goes
    // out once the connection is back (its confirmation then just arrives
    // after the timeout). Nudge the reconnect along.
    if (socket.disconnected) socket.connect();
    final result = Completer<DmSendResult>();
    final timeout = Timer(_sendTimeout, () {
      if (!result.isCompleted) result.complete(const DmSendResult.timedOut());
    });
    socket.emitWithAck('dm.send', {
      'conversationId': conversationId,
      'content': content,
      'contentType': contentType,
      'key': key,
      if (svg != null) 'svg': svg,
      if (png != null) 'png': png,
      if (duration != null) 'duration': duration,
      if (size != null) 'size': size,
      if (replyToId != null) 'replyToId': replyToId,
      if (replyToContent != null) 'replyToContent': replyToContent,
      if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
    }, ack: ([dynamic response]) {
      timeout.cancel();
      if (!result.isCompleted) result.complete(DmSendResult.fromAck(response));
    });
    return result.future;
  }

  void typing({
    required String conversationId,
    required bool isTyping,
    String? contentType,
  }) => _socket?.emit('dm.typing', {
    'conversationId': conversationId,
    'isTyping': isTyping,
    'contentType': contentType ?? '',
  });

  void markRead({required String conversationId, String? messageId}) =>
      _socket?.emit('dm.read', {
        'conversationId': conversationId,
        if (messageId != null) 'messageId': messageId,
      });

  void edit({required String messageId, required String content}) =>
      _socket?.emit('dm.edit', {'messageId': messageId, 'content': content});

  void deleteMessage({required String messageId}) =>
      _socket?.emit('dm.delete', {'messageId': messageId});

  /// Tells the backend the app language changed (it refreshes its copy of this
  /// user on the next request that isn't cached).
  void setLanguage(String value) {
    if (value == lang) return;
    lang = value;
    dio.options.headers['x-lang'] = value;
  }

  /// Stops chat pushes for this device and user (on sign-out).
  Future<void> unregisterDeviceToken(String token) => dio.delete<void>(
    '/chat/dm/device-token',
    data: {'token': token},
  );

  /// Registers this device's FCM token with the chat backend so the peer's
  /// messages arrive as push notifications when the app is closed.
  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) => dio.post<Map<String, dynamic>>(
    '/chat/dm/device-token',
    data: {'token': token, 'platform': platform},
  );

  /// Absolute URL — the server returns media paths relative to its origin.
  String absolute(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<void> dispose() async {
    _authRetryTimer?.cancel();
    _socket
      ?..clearListeners()
      ..disconnect()
      ..close();
    _socket = null;
    _connecting = null;
    await _events.close();
  }
}

/// The backend's answer to [DmApi.send].
class DmSendResult {
  const DmSendResult._({required this.ok, this.error, this.code});

  const DmSendResult.timedOut()
    : this._(ok: false, error: 'no confirmation in time');

  factory DmSendResult.fromAck(dynamic response) {
    final data = response is Map ? response : const <dynamic, dynamic>{};
    return DmSendResult._(
      ok: data['status'] == 'ok',
      error: data['error']?.toString() ?? 'unexpected reply',
      code: data['code']?.toString(),
    );
  }

  final bool ok;
  final String? error;
  final String? code;

  /// Refused for good — sending it again can't help (a block, or a message
  /// the backend won't take). Anything else (a timeout, rate limit, a server
  /// hiccup) is worth retrying.
  bool get isRejected =>
      !ok &&
      (code == 'BLOCKED' ||
          const {
            'Not a participant',
            'content must not be empty',
            'unsupported contentType',
            'conversationId and key are required',
          }.contains(error) ||
          (error?.startsWith('content is too long') ?? false));
}

/// A message from the server.
class DmMessage {
  DmMessage.fromJson(Map<dynamic, dynamic> json)
    : id = json['id']?.toString() ?? '',
      conversationId = json['conversationId']?.toString() ?? '',
      senderId = json['senderId']?.toString() ?? '',
      content = json['content']?.toString() ?? '',
      contentType = json['contentType']?.toString() ?? 'text',
      key = json['key']?.toString(),
      isRead = json['isRead'] == true,
      isEdited = json['isEdited'] == true,
      isDeleted = json['isDeleted'] == true,
      svg = json['svg']?.toString(),
      png = json['png']?.toString(),
      duration = json['duration']?.toString(),
      size = json['size']?.toString(),
      replyToId = json['replyToId']?.toString(),
      replyToContent = json['replyToContent']?.toString(),
      replyToSenderId = json['replyToSenderId']?.toString(),
      date =
          DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final String? key;
  final bool isRead;
  final bool isEdited;
  final bool isDeleted;
  final String? svg;

  /// Video thumbnail URL.
  final String? png;
  final String? duration;
  final String? size;

  /// Reply snapshot (denormalised on the server). Null = not a reply.
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderId;
  final DateTime date;

  ChatMessageKind get kind => switch (contentType) {
    'photo' => ChatMessageKind.photo,
    'video' => ChatMessageKind.video,
    'voice' => ChatMessageKind.voice,
    'document' || 'file' => ChatMessageKind.file,
    _ => ChatMessageKind.text,
  };
}

sealed class DmEvent {
  const DmEvent();
}

class DmMessageEvent extends DmEvent {
  const DmMessageEvent(this.message);
  final DmMessage message;
}

/// An existing message was edited or deleted (carries the updated snapshot).
class DmMessageUpdatedEvent extends DmEvent {
  const DmMessageUpdatedEvent(this.message);
  final DmMessage message;
}

class DmTypingEvent extends DmEvent {
  const DmTypingEvent({
    required this.conversationId,
    required this.isTyping,
    this.contentType,
  });
  final String conversationId;
  final bool isTyping;
  final String? contentType;
}

class DmReadEvent extends DmEvent {
  const DmReadEvent({
    required this.conversationId,
    this.messageId,
    this.all = false,
  });
  final String conversationId;
  final String? messageId;
  final bool all;
}

/// The peer went online / offline.
class DmPresenceEvent extends DmEvent {
  DmPresenceEvent({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
  });

  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
}

class DmConnectionEvent extends DmEvent {
  const DmConnectionEvent(this.status);
  final ChatConnectionStatus status;
}

/// Maps a plugin message kind to the backend `contentType` wire value.
String dmContentTypeOf(ChatMessageKind kind) => switch (kind) {
  ChatMessageKind.text => 'text',
  ChatMessageKind.photo => 'photo',
  ChatMessageKind.video => 'video',
  ChatMessageKind.voice => 'voice',
  ChatMessageKind.file => 'document',
};

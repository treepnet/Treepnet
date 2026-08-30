import 'dart:async';

import 'package:dio/dio.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Backend bilan ishlaydigan umumiy qatlam: bitta HTTP klient va bitta socket.
///
/// Chat ro'yxati va ochilgan suhbat bir xil socketdan foydalanadi - shuning
/// uchun suhbat ochiq bo'lganda ham ro'yxat real vaqtda yangilanib turadi.
class DmApi {
  DmApi({
    required this.baseUrl,
    required this.myUuid,
    required this.appName,
    required this.apiKey,
    required this.deviceId,
    required this.deviceName,
  });

  final String baseUrl;
  final String myUuid;
  final String appName;
  final String apiKey;
  final String deviceId;
  final String deviceName;

  late final Dio dio = Dio(BaseOptions(baseUrl: baseUrl, headers: _headers));

  io.Socket? _socket;
  final _events = StreamController<DmEvent>.broadcast();
  Completer<void>? _connecting;

  Map<String, String> get _headers => {
    'x-uuid': myUuid,
    'x-app': appName,
    'x-app-key': apiKey,
    'x-device-id': deviceId,
    'x-device-name': deviceName,
    'x-device-type': 'mobile',
    'x-lang': 'uz',
  };

  Stream<DmEvent> get events => _events.stream;

  /// Socketni bir marta ulaydi - takroriy chaqiruvlar o'sha ulanishni kutadi.
  Future<void> connect() {
    final existing = _connecting;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _connecting = completer;

    final socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders(_headers)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _events.add(const DmConnectionEvent(ChatConnectionStatus.connected));
      if (!completer.isCompleted) completer.complete();
    });
    socket.onDisconnect(
      (_) => _events.add(
        const DmConnectionEvent(ChatConnectionStatus.disconnected),
      ),
    );
    socket.onConnectError((e) {
      _events.add(const DmConnectionEvent(ChatConnectionStatus.error));
      if (!completer.isCompleted) completer.complete();
    });

    socket.on('dm.newMessage', (data) {
      if (data is Map) _events.add(DmMessageEvent(DmMessage.fromJson(data)));
    });
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
    socket.connect();
    return completer.future;
  }

  void send({
    required String conversationId,
    required String content,
    required String contentType,
    required String key,
    String? svg,
    String? png,
    String? duration,
    String? size,
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Socket ulanmagan');
    }
    socket.emit('dm.send', {
      'conversationId': conversationId,
      'content': content,
      'contentType': contentType,
      'key': key,
      if (svg != null) 'svg': svg,
      if (png != null) 'png': png,
      if (duration != null) 'duration': duration,
      if (size != null) 'size': size,
    });
  }

  void typing({required String conversationId, required bool isTyping, String? contentType}) =>
      _socket?.emit('dm.typing', {
        'conversationId': conversationId,
        'isTyping': isTyping,
        'contentType': contentType ?? '',
      });

  void markRead({required String conversationId, String? messageId}) =>
      _socket?.emit('dm.read', {
        'conversationId': conversationId,
        if (messageId != null) 'messageId': messageId,
      });

  /// To'liq manzil - server media yo'llarini nisbiy qaytaradi.
  String absolute(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<void> dispose() async {
    _socket
      ?..clearListeners()
      ..disconnect()
      ..close();
    _socket = null;
    _connecting = null;
    await _events.close();
  }
}

/// Serverdan kelgan xabar.
class DmMessage {
  DmMessage.fromJson(Map<dynamic, dynamic> json)
    : id = json['id']?.toString() ?? '',
      conversationId = json['conversationId']?.toString() ?? '',
      senderId = json['senderId']?.toString() ?? '',
      content = json['content']?.toString() ?? '',
      contentType = json['contentType']?.toString() ?? 'text',
      key = json['key']?.toString(),
      isRead = json['isRead'] == true,
      svg = json['svg']?.toString(),
      png = json['png']?.toString(),
      duration = json['duration']?.toString(),
      size = json['size']?.toString(),
      date = DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now();

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String contentType;
  final String? key;
  final bool isRead;
  final String? svg;

  /// Video thumbnail manzili.
  final String? png;
  final String? duration;
  final String? size;
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

/// Suhbatdosh onlayn/oflayn bo'ldi.
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

/// `contentType` nomini plagin turiga o'girish.
String dmContentTypeOf(ChatMessageKind kind) => switch (kind) {
  ChatMessageKind.text => 'text',
  ChatMessageKind.photo => 'photo',
  ChatMessageKind.video => 'video',
  ChatMessageKind.voice => 'voice',
  ChatMessageKind.file => 'document',
};

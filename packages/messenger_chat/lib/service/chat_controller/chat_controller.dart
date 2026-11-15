import 'dart:async';
import 'package:messenger_chat/data/enum/chat_connection_status.dart';

class ChatController<T> {
  final _controller = StreamController<T>.broadcast();
  final _typingController = StreamController<TypingStatus>.broadcast();
  final _connectionController =
      StreamController<ChatConnectionStatus>.broadcast();

  ChatConnectionStatus _connectionStatus = ChatConnectionStatus.disconnected;
  ChatConnectionStatus get connectionStatus => _connectionStatus;

  T? _value;
  T? get value => _value;

  /// Typing statusini yangilash
  void updateTyping(bool isTyping, String type, {String? userName}) {
    _typingController.add(
      TypingStatus(isTyping: isTyping, type: type, userName: userName),
    );
  }

  /// Real-time oqim
  Stream<T> get stream => _controller.stream;

  /// Typing oqimi
  Stream<TypingStatus> get typingStream => _typingController.stream;

  /// Connection oqimi
  Stream<ChatConnectionStatus> get connectionStream =>
      _connectionController.stream;

  /// Yangi qiymat berish
  void update(T newValue) {
    _value = newValue;
    _controller.add(newValue);
  }

  /// Connection statusini yangilash
  void updateConnection(ChatConnectionStatus status) {
    _connectionStatus = status;
    _connectionController.add(status);
  }

  /// Typing statusini yangilash

  bool get connectionStreamIsClosed => _connectionController.isClosed;

  void dispose() {
    _controller.close();
    _typingController.close();
    _connectionController.close();
  }
}

class TypingStatus {
  final bool isTyping;
  final String type;
  final String? userName;

  TypingStatus({required this.isTyping, required this.type, this.userName});
}

// part of messenger_chat;

enum ChatConnectionStatus {
  connecting,
  connected,
  disconnected,
  error;

  bool get isConnected => this == ChatConnectionStatus.connected;
  bool get isConnecting => this == ChatConnectionStatus.connecting;
  bool get isDisconnected => this == ChatConnectionStatus.disconnected;
  bool get isError => this == ChatConnectionStatus.error;
}

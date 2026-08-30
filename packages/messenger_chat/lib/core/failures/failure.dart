part of messenger_chat;

abstract class _Failure extends Equatable {
  const _Failure({required this.message, required this.code});

  final String message;
  final num code;
}

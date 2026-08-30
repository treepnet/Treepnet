part of messenger_chat;

class _ServerException extends Equatable implements Exception {
  const _ServerException({required this.errorMessage, required this.errorCode});

  final String errorMessage;
  final num errorCode;

  @override
  List<Object?> get props => [errorMessage, errorCode];
}

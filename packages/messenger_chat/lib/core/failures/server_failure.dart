part of messenger_chat;

final class _ServerFailure extends _Failure {
  const _ServerFailure({required super.message, required super.code});

  factory _ServerFailure.fromException(_ServerException exception) =>
      _ServerFailure(
        message: exception.errorMessage,
        code: exception.errorCode,
      );

  @override
  List<Object?> get props => [message, code];
}

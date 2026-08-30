part of messenger_chat;

Future<_Either<_Failure, T>> _handleDataSource<T>(
  Future<T> Function() callback,
) async {
  try {
    final data = await callback();

    return _Right(data);
  } on _ServerException catch (exception) {
    return _Left(_ServerFailure.fromException(exception));
  }
}

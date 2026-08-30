part of messenger_chat;

Future<T> _handleRequest<T>(Future<T> Function() callback) async {
  try {
    return await callback();
  } on DioException catch (error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      throw const _ServerException(errorMessage: 'timeout', errorCode: 408);
    }
    throw _ServerException(
      errorMessage: error.message ?? '',
      errorCode: error.response?.statusCode ?? 500,
    );
  } on _ServerException {
    rethrow;
  } catch (error, _) {
    throw _ServerException(errorMessage: '$error', errorCode: 141);
  }
}

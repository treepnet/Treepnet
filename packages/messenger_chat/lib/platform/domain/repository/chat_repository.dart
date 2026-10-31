part of messenger_chat;

abstract class _ChatRepository {
  Future<_Either<_Failure, _MessageResponse>> getMessages(_ParamsGetMessage params);
}

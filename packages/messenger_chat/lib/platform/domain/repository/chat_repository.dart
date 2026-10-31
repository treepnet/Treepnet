part of messenger_chat;

abstract class _ChatRepository {
  Future<_Either<_Failure, _MessageResponse>> getMessages(_ParamsGetMessage params);

  /// Saved on the phone; null when there's nothing.
  Future<_MessageResponse?> cachedMessages();
}

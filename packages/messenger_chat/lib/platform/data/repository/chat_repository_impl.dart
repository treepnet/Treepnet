part of messenger_chat;

final class ChatRepositoryImpl implements _ChatRepository {
  final chatNetworkDataSource = _ChatNetworkDataSource();

  @override
  Future<_Either<_Failure, _MessageResponse>> getMessages(_ParamsGetMessage params) =>
      _handleDataSource<_MessageResponse>(() => chatNetworkDataSource.getMessages(params));

  @override
  Future<_MessageResponse?> cachedMessages() =>
      chatNetworkDataSource.getCachedMessages();
}

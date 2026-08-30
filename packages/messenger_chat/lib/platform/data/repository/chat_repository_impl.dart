part of messenger_chat;

final class ChatRepositoryImpl implements _ChatRepository {
  final chatNetworkDataSource = _ChatNetworkDataSource();

  @override
  Future<_Either<_Failure, _MessageResponse>> getMessages(_ParamsGetMessage params) =>
      _handleDataSource<_MessageResponse>(() => chatNetworkDataSource.getMessages(params));



  @override
  Future<_Either<_Failure, _UploadResponse>> uploadMessage(_UploadParams params) =>
      _handleDataSource<_UploadResponse>(() => chatNetworkDataSource.uploadMessage(params));
}

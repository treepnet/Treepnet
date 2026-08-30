part of messenger_chat;

abstract class _ChatRepository {
  Future<_Either<_Failure, _MessageResponse>> getMessages(_ParamsGetMessage params);



  Future<_Either<_Failure, _UploadResponse>> uploadMessage(_UploadParams params);
}

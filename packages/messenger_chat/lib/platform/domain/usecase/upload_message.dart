part of messenger_chat;

final class _UploadMessageUseCase
    implements _UseCase<_UploadResponse, _UploadParams> {
  _UploadMessageUseCase({required this.repository});

  final _ChatRepository repository;

  @override
  Future<_Either<_Failure, _UploadResponse>> call(params) =>
      repository.uploadMessage(params);
}

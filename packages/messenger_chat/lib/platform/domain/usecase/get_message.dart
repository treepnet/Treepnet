part of messenger_chat;

final class _GetMessageUseCase
    extends _UseCase<_MessageResponse, _ParamsGetMessage> {
  _GetMessageUseCase({required this.chatRepository});

  final _ChatRepository chatRepository;

  @override
  Future<_Either<_Failure, _MessageResponse>> call(params) =>
      chatRepository.getMessages(params);
}

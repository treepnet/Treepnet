part of messenger_chat;

abstract class _UseCase<Type, Params> {
  const _UseCase();

  Future<_Either<_Failure, Type>> call(Params params);
}

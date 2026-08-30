part of messenger_chat;

class _Right<L, R> extends _Either<L, R> with EquatableMixin {
  const _Right(this.value);

  final R value;

  @override
  List<Object?> get props => [value];
}

part of messenger_chat;

class _Left<L, R> extends _Either<L, R> with EquatableMixin {
  const _Left(this.value);

  final L value;

  @override
  List<Object?> get props => [value];
}

part of messenger_chat;

final class _ParamsGetMessage extends Equatable {
  const _ParamsGetMessage({this.page, this.size});

  final int? page;

  final int? size;

  @override
  List<Object?> get props => [page, size];
}

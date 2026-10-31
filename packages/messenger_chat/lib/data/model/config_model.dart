part of messenger_chat;

/// What the chat UI lets you do. Text only now: photo, video, voice and file
/// messages were never turned on, and their code is gone.
class _ConfigModel extends Equatable {
  const _ConfigModel({required this.textIsBlock});

  _ConfigModel copyWith({bool? textIsBlock}) =>
      _ConfigModel(textIsBlock: textIsBlock ?? this.textIsBlock);

  static _ConfigModel get initial => const _ConfigModel(textIsBlock: false);

  final bool textIsBlock;

  @override
  List<Object?> get props => [textIsBlock];
}

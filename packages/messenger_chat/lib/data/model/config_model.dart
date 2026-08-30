part of messenger_chat;

class _ConfigModel extends Equatable {
  const _ConfigModel({
    required this.videoIsBlock,
    required this.textIsBlock,
    required this.voiceIsBlock,
    required this.photoIsBlock,
    required this.documentIsBlock,
  });

  factory _ConfigModel.fromJson(Map<String, dynamic> json) => _ConfigModel(
    videoIsBlock: json['videoIsBlock'] ?? false,
    textIsBlock: json['textIsBlock'] ?? false,
    voiceIsBlock: json['voiceIsBlock'] ?? false,
    photoIsBlock: json['photoIsBlock'] ?? false,
    documentIsBlock: json['documentIsBlock'] ?? false,
  );

  _ConfigModel copyWith({
    bool? videoIsBlock,
    bool? textIsBlock,
    bool? voiceIsBlock,
    bool? photoIsBlock,
    bool? documentIsBlock,
  }) => _ConfigModel(
    videoIsBlock: videoIsBlock ?? this.videoIsBlock,
    textIsBlock: textIsBlock ?? this.textIsBlock,
    voiceIsBlock: voiceIsBlock ?? this.voiceIsBlock,
    photoIsBlock: photoIsBlock ?? this.photoIsBlock,
    documentIsBlock: documentIsBlock ?? this.documentIsBlock,
  );

 static _ConfigModel get initial => const _ConfigModel(
    videoIsBlock: false,
    textIsBlock: false,
    voiceIsBlock: false,
    photoIsBlock: false,
    documentIsBlock: false,
  );

  final bool videoIsBlock;
  final bool textIsBlock;
  final bool voiceIsBlock;
  final bool photoIsBlock;
  final bool documentIsBlock;


   bool get attachmentIsBlock => videoIsBlock && photoIsBlock && documentIsBlock;

  @override
  List<Object?> get props => [
    videoIsBlock,
    textIsBlock,
    voiceIsBlock,
    photoIsBlock,
    documentIsBlock,
  ];
}

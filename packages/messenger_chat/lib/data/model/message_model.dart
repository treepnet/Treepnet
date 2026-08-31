part of messenger_chat;

class _MessageModel extends Equatable {
  const _MessageModel({
    required this.id,
    required this.content,
    required this.status,
    required this.formattedTime,
    required this.date,
    required this.key,
    required this.isMine,
    required this.senderId,
    required this.senderName,
    required this.contentType,
    required this.isRead,
    this.filePath,
    this.sendMessage,
    this.uploadProgress,
    this.width,
    this.height,
    this.replyTo,
  });

  /// Transportdan kelgan xabarni UI modeliga aylantiradi.
  ///
  /// [myId] - hozirgi foydalanuvchi identifikatori; xabar qaysi tomonda
  /// chizilishi shu solishtiruv bilan aniqlanadi.
  factory _MessageModel.fromIncoming(
    ChatIncomingMessage message, {
    required String myId,
  }) => _MessageModel(
    id: message.id,
    status: MessageStatus.fromBool(value: message.isRead),
    content: Message(
      content: message.content,
      svg: message.waveformUrl ?? '',
      png: message.thumbnailUrl ?? '',
      duration: message.duration ?? '',
      size: message.size ?? '',
    ),
    formattedTime: _DateUtility.getFormattedTime(
      message.sentAt.toIso8601String(),
    ),
    date: message.sentAt.toIso8601String(),
    key: message.clientKey ?? '',
    isMine: message.senderId == myId,
    senderId: message.senderId,
    senderName: message.senderName ?? '',
    contentType: _ContentType.fromKind(message.kind),
    isRead: message.isRead,
    uploadProgress: 0,
    replyTo: message.replyTo,
  );

  /// Serverdagi identifikator. Bo'sh satr - xabar hali yuborilmagan
  /// (optimistik) nusxa ekanini bildiradi.
  final String id;
  final MessageStatus status;
  final Message content;
  final String formattedTime;
  final String date;
  final String key;
  final double? width;
  final double? height;
  final String? filePath;

  /// Xabar shu qurilmadagi foydalanuvchidan bo'lsa `true` - o'ng tomonda
  /// chiziladi.
  final bool isMine;
  final String senderId;

  /// Guruh suhbatlarida jo'natuvchi ismi. 1:1 da bo'sh qoladi.
  final String senderName;
  final _ContentType contentType;
  final bool isRead;
  final bool? sendMessage;
  final double? uploadProgress;

  /// Bu xabar javob bo'lsa - javob berilgan xabarning iqtibosi.
  final ChatReplyInfo? replyTo;

  _MessageModel copyWith({
    String? id,
    Message? content,
    MessageStatus? status,
    String? formattedTime,
    String? date,
    String? key,
    bool? isMine,
    String? senderId,
    String? senderName,
    double? width,
    double? height,
    String? filePath,
    _ContentType? contentType,
    bool? isRead,
    bool? sendMessage,
    double? uploadProgress,
    ChatReplyInfo? replyTo,
  }) => _MessageModel(
    id: id ?? this.id,
    width: width ?? this.width,
    height: height ?? this.height,
    content: content ?? this.content,
    status: status ?? this.status,
    formattedTime: formattedTime ?? this.formattedTime,
    date: date ?? this.date,
    filePath: filePath ?? this.filePath,
    key: key ?? this.key,
    isMine: isMine ?? this.isMine,
    senderId: senderId ?? this.senderId,
    senderName: senderName ?? this.senderName,
    contentType: contentType ?? this.contentType,
    isRead: isRead ?? this.isRead,
    sendMessage: sendMessage ?? this.sendMessage,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    replyTo: replyTo ?? this.replyTo,
  );

  /// Hali yuborilmagan (optimistik) xabar uchun asos.
  static _MessageModel initial = const _MessageModel(
    id: '',
    content: Message(content: ''),
    formattedTime: '',
    status: MessageStatus.delivered,
    date: '',
    key: '',
    isMine: true,
    senderId: '',
    senderName: '',
    contentType: _ContentType.text,
    isRead: false,
    uploadProgress: 0,
  );

  /// Serverdan kelgan sahifani UI modeliga aylantiradi.
  static List<_MessageModel> fromHistory(
    ChatHistoryPage page, {
    required String myId,
  }) => page.messages
      .map((m) => _MessageModel.fromIncoming(m, myId: myId))
      .toList();

  /// Xabar suhbatdoshdan kelgan - chap tomonda chiziladi.
  bool get isFromPeer => !isMine;

  /// Serverda hali mavjud emas (yuborilmoqda yoki xato bo'lgan).
  bool get isLocal => id.isEmpty;

  bool get fileIsNotEmpty => content.content.isNotEmpty;

  String get time => _DateUtility.getFormattedTime(date);

  /// Ovozli xabarning to'lqin shakli - transport to'liq manzil beradi.
  String get voiceWave => content.svg;

  bool get isReadMessage => isRead;

  @override
  List<Object?> get props => [
    key,
    id,
    status,
    sendMessage,
    content,
    formattedTime,
    date,
    isMine,
    senderId,
    senderName,
    contentType,
    isRead,
    uploadProgress,
    time,
    voiceWave,
    replyTo?.messageId,
  ];
}

class _MessageData extends Equatable {
  const _MessageData({this.svg, this.size, this.png, this.duration});

  factory _MessageData.fromJson(Map<String, dynamic> json) => _MessageData(
    svg: json['svg'],
    size: json['size'] != null ? json['size'].toString() : null,
    png: json['png'],
    duration: json['duration'] != null ? json['duration'].toString() : null,
  );
  final String? svg;
  final String? png;
  final String? duration;
  final String? size;

  Map<String, dynamic> toJson() => {
    'svg': svg,
    'size': size,
    'png': png,
    'duration': duration,
  };

  @override
  List<Object?> get props => [svg, size, png, duration];
}

class Message extends Equatable {
  const Message({
    required this.content,
    this.svg = '',
    this.size = '',
    this.png = '',
    this.duration = '',
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    content: json['content']?.toString() ?? '',
    svg: json['data'] != null
        ? _MessageData.fromJson(json['data']).svg ?? ''
        : '',
    size: json['data'] != null
        ? _MessageData.fromJson(json['data']).size.toString()
        : '',
    png: json['data'] != null
        ? _MessageData.fromJson(json['data']).png ?? ''
        : '',
    duration: json['data'] != null
        ? _MessageData.fromJson(json['data']).duration ?? ''
        : '',
  );

  final String content;
  final String svg;
  final String size;
  final String png;
  final String duration;

  @override
  List<Object?> get props => [content, svg, size];
}

class _MessageResponse extends Equatable {
  factory _MessageResponse.fromJson(Map<String, dynamic> json) =>
      _MessageResponse(
        totalPage: json['totalPage'] as int? ?? 0,
        currentPage: json['currentPage'] as int? ?? 0,
        totalItems: json['totalItems'] as int? ?? 0,
        hasNextPage: json['hasNextPage'] as bool? ?? false,
        hasPreviousPage: json['hasPreviousPage'] as bool? ?? false,
        messages: const <_MessageModel>[],
      );

  const _MessageResponse({
    required this.totalPage,
    required this.totalItems,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.messages,
    required this.currentPage,
  });

  final int totalPage;
  final int currentPage;
  final int totalItems;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final List<_MessageModel> messages;

  _MessageResponse copyWith({
    int? totalPage,
    int? currentPage,
    int? totalItems,
    bool? hasNextPage,
    bool? hasPreviousPage,
    List<_MessageModel>? messages,
  }) => _MessageResponse(
    totalPage: totalPage ?? this.totalPage,
    currentPage: currentPage ?? this.currentPage,
    totalItems: totalItems ?? this.totalItems,
    hasNextPage: hasNextPage ?? this.hasNextPage,
    hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
    messages: messages ?? this.messages,
  );

  static _MessageResponse get initial => const _MessageResponse(
    totalPage: 0,
    currentPage: 0,
    totalItems: 0,
    hasNextPage: true,
    hasPreviousPage: false,
    messages: [],
  );

  @override
  List<Object?> get props => [
    totalPage,
    currentPage,
    totalItems,
    hasNextPage,
    hasPreviousPage,
    messages,
  ];
}

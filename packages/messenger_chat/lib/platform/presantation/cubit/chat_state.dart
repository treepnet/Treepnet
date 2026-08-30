part of messenger_chat;

class ChatState extends Equatable {
  const ChatState({
    required this.isLoading,
    required this.isLoadMore,
    required this.failure,
    required this.messages,
    required this.config,
    required this.isTyping,
    required this.typingType,
    required this.typingName,
    required this.isBackgroundApp,
    required this.unreadCount,
  });

  final String failure;
  final _ConfigModel config;
  final bool isTyping;
  final String typingType;
  final String? typingName;
  final bool isLoadMore;
  final bool isLoading;
  final bool isBackgroundApp;
  final int unreadCount;

  final _MessageResponse messages;

  static ChatState initial = ChatState(
    failure: '',
    config: _ConfigModel.initial,
    messages: _MessageResponse.initial,
    isTyping: false,
    typingType: '',
    typingName: null,
    isLoadMore: false,
    isLoading: false,
    isBackgroundApp: false,
    unreadCount: 0,
  );

  ChatState copyWith({
    _MessageResponse? messages,
    _ConfigModel? config,
    String? failure,
    bool? isTyping,
    String? typingType,
    String? typingName,
    bool? isLoadMore,
    bool? isLoading,
    bool? isBackgroundApp,
    int? unreadCount,
  }) => ChatState(
    config: config ?? this.config,
    messages: messages ?? this.messages,
    failure: failure ?? this.failure,
    isTyping: isTyping ?? this.isTyping,
    typingType: typingType ?? this.typingType,
    typingName: typingName ?? this.typingName,
    isLoadMore: isLoadMore ?? this.isLoadMore,
    isLoading: isLoading ?? this.isLoading,
    isBackgroundApp: isBackgroundApp ?? this.isBackgroundApp,
    unreadCount: unreadCount ?? this.unreadCount,
  );

  @override
  List<Object> get props => [
    messages,
    failure,
    isLoading,
    isTyping,
    typingType,
    typingName ?? '',
    isLoadMore,
    isBackgroundApp,
    config,
    unreadCount,
  ];
}

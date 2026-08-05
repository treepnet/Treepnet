part of 'chat_bloc.dart';

enum ChatStatus { initial, loading, success, failure }

@JsonSerializable()
class ChatState extends Equatable {
  const ChatState({
    required this.status,
    required this.messages,
    required this.hasMore,
    // Runtime-only (not persisted). The default keeps the generated fromJson —
    // which doesn't pass it — valid, so no regeneration is needed.
    this.failedIds = const {},
    this.otherReadAt,
  });

  factory ChatState.fromJson(Map<String, dynamic> json) =>
      _$ChatStateFromJson(json);

  const ChatState.initial()
    : this(status: ChatStatus.initial, messages: const [], hasMore: true);

  final ChatStatus status;
  final bool hasMore;
  final List<Message> messages;

  /// Ids of optimistic messages whose send failed — rendered with a retry
  /// affordance, and re-sendable from the "not sent" snackbar.
  final Set<String> failedIds;

  /// The other participant's synced "last read" time; my messages older than
  /// it show ✓✓. Runtime-only.
  final DateTime? otherReadAt;

  @override
  List<Object?> get props => [status, messages, hasMore, failedIds, otherReadAt];

  ChatState copyWith({
    ChatStatus? status,
    List<Message>? messages,
    bool? hasMore,
    Set<String>? failedIds,
    DateTime? otherReadAt,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      failedIds: failedIds ?? this.failedIds,
      otherReadAt: otherReadAt ?? this.otherReadAt,
    );
  }

  Map<String, dynamic> toJson() => _$ChatStateToJson(this);
}

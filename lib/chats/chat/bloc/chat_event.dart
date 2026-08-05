part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => [];
}

final class ChatMessageChanged extends ChatEvent {
  const ChatMessageChanged(this.payload);

  final ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord})
  payload;
}

final class ChatMessagesFetchRequested extends ChatEvent {
  const ChatMessagesFetchRequested();
}

final class ChatSendMessageRequested extends ChatEvent {
  const ChatSendMessageRequested({
    required this.sender,
    required this.receiver,
    required this.message,
  });

  final User sender;
  final User receiver;
  final Message message;
}

final class ChatMessageDeleteRequested extends ChatEvent {
  const ChatMessageDeleteRequested(this.messageId);

  final String messageId;
}

final class ChatMessageSeen extends ChatEvent {
  const ChatMessageSeen(this.messageId);

  final String messageId;
}

/// Fired when the chat is opened: bulk-marks all incoming messages read so the
/// inbox unread badge clears.
final class ChatMarkReadRequested extends ChatEvent {
  const ChatMarkReadRequested(this.userId);

  final String userId;

  @override
  List<Object> get props => [userId];
}

/// A throttled "I'm typing" heartbeat for the current user in this chat.
final class ChatTypingRequested extends ChatEvent {
  const ChatTypingRequested(this.userId);

  final String userId;

  @override
  List<Object> get props => [userId];
}

/// The other participant's synced "last read" time changed (drives ✓✓).
final class ChatOtherReadAtChanged extends ChatEvent {
  const ChatOtherReadAtChanged(this.readAt);

  final DateTime? readAt;

  @override
  List<Object> get props => [readAt?.toIso8601String() ?? ''];
}

final class ChatMessageEditRequested extends ChatEvent {
  const ChatMessageEditRequested({
    required this.newMessage,
    required this.oldMessage,
  });

  final Message oldMessage;
  final Message newMessage;

  @override
  List<Object> get props => [oldMessage, newMessage];
}

part of messenger_chat;


enum MessageStatus {

  sending,
  delivered,
  error,
  seen;

  static MessageStatus fromString(String value) {
    switch (value) {
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'error':
        return MessageStatus.error;
      case 'seen':
        return MessageStatus.seen;
      default:
        return MessageStatus.sending;
    }
  }

 static  MessageStatus fromBool({required bool value}) {
    if (value) {
      return MessageStatus.seen;
    } else {
      return MessageStatus.delivered;
    }
  }

  bool get isSending => this == MessageStatus.sending;

  bool get isDelivered => this == MessageStatus.delivered;

  bool get isError => this == MessageStatus.error;

  bool get isSeen => this == MessageStatus.seen;
}

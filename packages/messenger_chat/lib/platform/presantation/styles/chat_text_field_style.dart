part of messenger_chat;

class ChatTextFieldStyle {
  const ChatTextFieldStyle({
    required this.sendIconPath,
    required this.closeIconPath,
    required this.microphoneIconPath,
    required this.attachmentIconPath,
    required this.attachmentIconColor,
    required this.sendIconColor,
    required this.microphoneIconColor,
    required this.microphoneBackgroundColor,
    required this.closeIconColor,
    required this.enabledBorderColor,
    required this.focusedBorderColor,
    this.inputBackgroundColor,
    this.closeBackgroundColor,
    this.inputFillColor,
    this.attachmentBackgroundColor,
    this.sendBackgroundColor,
    this.inputCursorColor,
    this.inputHintTextStyle,
    this.inputTextStyle,
    this.onSendMessage,
    this.cancelRecordingTextStyle,
    this.onSendAttachment,
  });
  final String closeIconPath;
  final String microphoneIconPath;
  final Color? inputBackgroundColor;
  final Color? inputFillColor;
  final Color? inputCursorColor;
  final Color? closeBackgroundColor;
  final Color closeIconColor;
  final Color focusedBorderColor;
  final Color enabledBorderColor;
  final Color attachmentIconColor;
  final Color sendIconColor;
  final Color? sendBackgroundColor;
  final Color microphoneIconColor;
  final Color microphoneBackgroundColor;
  final Color? attachmentBackgroundColor;
  final TextStyle? inputHintTextStyle;
  final TextStyle? inputTextStyle;
  final TextStyle? cancelRecordingTextStyle;
  final VoidCallback? onSendAttachment;
  final VoidCallback? onSendMessage;

  final String attachmentIconPath;

  final String sendIconPath;

  ChatTextFieldStyle copyWith({
    String? closeIconPath,
    String? microphoneIconPath,
    Color? inputBackgroundColor,
    Color? closeIconColor,
    Color? closeBackgroundColor,
    Color? inputFillColor,
    Color? inputCursorColor,
    Color? attachmentIconColor,
    Color? sendIconColor,
    Color? microphoneIconColor,
    Color? microphoneBackgroundColor,
    Color? attachmentBackgroundColor,
    Color? sendBackgroundColor,
    Color? focusedBorderColor,
    Color? enabledBorderColor,
    TextStyle? inputHintTextStyle,
    TextStyle? cancelRecordingTextStyle,
    TextStyle? inputTextStyle,
    VoidCallback? onSendAttachment,
    VoidCallback? onSendMessage,
    String? sendIconPath,
    String? attachmentIconPath,
  }) => ChatTextFieldStyle(
    closeIconPath: closeIconPath ?? this.closeIconPath,
    microphoneIconPath: microphoneIconPath ?? this.microphoneIconPath,
    inputTextStyle: inputTextStyle ?? this.inputTextStyle,
    inputFillColor: inputFillColor ?? this.inputFillColor,
    inputCursorColor: inputCursorColor ?? this.inputCursorColor,
    inputHintTextStyle: inputHintTextStyle ?? this.inputHintTextStyle,
    inputBackgroundColor: inputBackgroundColor ?? this.inputBackgroundColor,
    closeBackgroundColor: closeBackgroundColor ?? this.closeBackgroundColor,
    enabledBorderColor: enabledBorderColor ?? this.enabledBorderColor,
    focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
    closeIconColor: closeIconColor ?? this.closeIconColor,
    onSendMessage: onSendMessage ?? this.onSendMessage,
    onSendAttachment: onSendAttachment ?? this.onSendAttachment,
    attachmentIconPath: attachmentIconPath ?? this.attachmentIconPath,
    cancelRecordingTextStyle: cancelRecordingTextStyle ?? this.cancelRecordingTextStyle,
    sendIconPath: sendIconPath ?? this.sendIconPath,
    attachmentIconColor: attachmentIconColor ?? this.attachmentIconColor,
    sendIconColor: sendIconColor ?? this.sendIconColor,
    microphoneIconColor: microphoneIconColor ?? this.microphoneIconColor,
    microphoneBackgroundColor:
        microphoneBackgroundColor ?? this.microphoneBackgroundColor,
    attachmentBackgroundColor:
        attachmentBackgroundColor ?? this.attachmentBackgroundColor,
    sendBackgroundColor: sendBackgroundColor ?? this.sendBackgroundColor,
  );
}

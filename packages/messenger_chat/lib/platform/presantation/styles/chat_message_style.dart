part of messenger_chat;

class ChatMessageStyle {
  const ChatMessageStyle({
    required this.clientMessageTextStyle,
    required this.adminMessageTextStyle,
    required this.dateSeparatorTextStyle,
    required this.adminMessageTimeTextStyle,
    required this.clientMessageTimeTextStyle,
    required this.adminMessageBackgroundColor,
    required this.clientMessageBackgroundColor,
    required this.readIconColor,
    required this.adminProfileBackgroundColor,
    required this.adminAuthorTextColor,
    required this.clientAudioPlayIconColor,
    required this.clientAudioWaveColor,
    required this.adminAudioPlayIconColor,
    required this.adminAudioWaveColor,
    required this.fileIconColor,
    required this.adminProfileIconSvg,
    required this.fileIconSvg,

  });
  final TextStyle clientMessageTextStyle;
  final TextStyle adminMessageTextStyle;
  final TextStyle adminMessageTimeTextStyle;
  final TextStyle clientMessageTimeTextStyle;
  final TextStyle dateSeparatorTextStyle;
  final Color adminMessageBackgroundColor;
  final Color clientMessageBackgroundColor;
  final Color readIconColor;
  final Color adminProfileBackgroundColor;
  final Color adminAuthorTextColor;
  final Color clientAudioPlayIconColor;
  final Color adminAudioPlayIconColor;
  final Color clientAudioWaveColor;
  final Color adminAudioWaveColor;
  final Color fileIconColor;
  final String adminProfileIconSvg;
  final String fileIconSvg ;

  ChatMessageStyle copyWith({
    TextStyle? clientMessageTextStyle,
    TextStyle? adminMessageTextStyle,
    TextStyle? adminMessageTimeTextStyle,
    TextStyle? clientMessageTimeTextStyle,
    TextStyle? dateSeparatorTextStyle,
    Color? adminMessageBackgroundColor,
    Color? clientMessageBackgroundColor,
    Color? readIconColor,
    Color? fileIconColor,
    Color? adminProfileBackgroundColor,
    Color? adminAuthorTextColor,
    Color? clientAudioPlayIconColor,
    Color? clientAudioWaveColor,
    Color? adminAudioWaveColor,
    Color? adminAudioPlayIconColor,
    String? adminProfileIconSvg,
    String? fileIconSvg,
  }) => ChatMessageStyle(
    clientMessageTextStyle:
        clientMessageTextStyle ?? this.clientMessageTextStyle,
    adminMessageTextStyle: adminMessageTextStyle ?? this.adminMessageTextStyle,
    fileIconSvg: fileIconSvg ?? this.fileIconSvg,
    adminProfileIconSvg: adminProfileIconSvg ?? this.adminProfileIconSvg,
    fileIconColor: fileIconColor ?? this.fileIconColor,
    adminMessageTimeTextStyle:
        adminMessageTimeTextStyle ?? this.adminMessageTimeTextStyle,
    dateSeparatorTextStyle:
        dateSeparatorTextStyle ?? this.dateSeparatorTextStyle,
    adminProfileBackgroundColor:
        adminProfileBackgroundColor ?? this.adminProfileBackgroundColor,
    clientMessageTimeTextStyle:
        clientMessageTimeTextStyle ?? this.clientMessageTimeTextStyle,
    adminMessageBackgroundColor:
        adminMessageBackgroundColor ?? this.adminMessageBackgroundColor,
    readIconColor: readIconColor ?? this.readIconColor,
    adminAuthorTextColor: adminAuthorTextColor ?? this.adminAuthorTextColor,
    clientAudioPlayIconColor: clientAudioPlayIconColor ?? this.clientAudioPlayIconColor,
    clientAudioWaveColor: clientAudioWaveColor ?? this.clientAudioWaveColor,
    adminAudioWaveColor: adminAudioWaveColor ?? this.adminAudioWaveColor,
    adminAudioPlayIconColor: adminAudioPlayIconColor ?? this.adminAudioPlayIconColor,
    clientMessageBackgroundColor:
        clientMessageBackgroundColor ?? this.clientMessageBackgroundColor,
  );
}

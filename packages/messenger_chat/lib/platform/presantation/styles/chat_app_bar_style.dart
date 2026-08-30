part of messenger_chat;

class ChatAppBarStyle {
  const ChatAppBarStyle({
    required this.profileBackgroundColor,
    required this.profileIconSvgPath,
    required this.backIconSvgPath,
    this.titleTextStyle,
    this.labelTextStyle,
    this.statusTextStyle,
    this.backgroundColor = Colors.white,
    this.profileIconColor = Colors.white,
    this.backIconSvgColor = Colors.black,
    this.typingTextColor = Colors.blueAccent,
    this.onlineColor = Colors.green,
    this.offlineColor = Colors.grey,
    this.elevation = 0,
    this.shadowColor,
    this.centerTitle = false,
    this.onBackButton,
  });

  final TextStyle? titleTextStyle;
  final TextStyle? labelTextStyle;
  final TextStyle? statusTextStyle;
  final Color backgroundColor;
  final Color profileBackgroundColor;
  final Color profileIconColor;
  final Color backIconSvgColor;
  final Color typingTextColor;
  final Color onlineColor;
  final Color offlineColor;
  final double elevation;
  final Color? shadowColor;
  final bool centerTitle;
  final String backIconSvgPath;
  final String profileIconSvgPath;

  final VoidCallback? onBackButton;

  ChatAppBarStyle copyWith({
    TextStyle? titleTextStyle,
    TextStyle? labelTextStyle,
    TextStyle? statusTextStyle,
    Color? backgroundColor,
    Color? backIconSvgColor,
    Color? profileIconColor,
    Color? profileBackgroundColor,
    Color? typingTextColor,
    Color? onlineColor,
    Color? offlineColor,
    double? elevation,
    Color? shadowColor,
    bool? centerTitle,
    VoidCallback? onBackButton,
    String? profileIconSvgPath,
    String? backIconSvgPath,
  }) => ChatAppBarStyle(
    titleTextStyle: titleTextStyle ?? this.titleTextStyle,
    labelTextStyle: labelTextStyle ?? this.labelTextStyle,
    statusTextStyle: statusTextStyle ?? this.statusTextStyle,
    profileBackgroundColor:
        profileBackgroundColor ?? this.profileBackgroundColor,
    profileIconColor: profileIconColor ?? this.profileIconColor,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    backIconSvgColor: backIconSvgColor ?? this.backIconSvgColor,
    typingTextColor: typingTextColor ?? this.typingTextColor,
    onlineColor: onlineColor ?? this.onlineColor,
    offlineColor: offlineColor ?? this.offlineColor,
    elevation: elevation ?? this.elevation,
    shadowColor: shadowColor ?? this.shadowColor,
    centerTitle: centerTitle ?? this.centerTitle,
    onBackButton: onBackButton ?? this.onBackButton,
    profileIconSvgPath: profileIconSvgPath ?? this.profileIconSvgPath,
    backIconSvgPath: backIconSvgPath ?? this.backIconSvgPath,
  );
}

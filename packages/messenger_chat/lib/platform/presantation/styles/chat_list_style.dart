part of messenger_chat;

/// Chat ro'yxatining ko'rinishi.
class ChatListStyle {
  const ChatListStyle({
    this.backgroundColor = Colors.white,
    this.avatarBackgroundColor = const Color(0xff1064FF),
    this.avatarTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    this.titleTextStyle = const TextStyle(
      color: Color(0xff111827),
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    this.previewTextStyle = const TextStyle(
      color: Color(0xff6B7280),
      fontSize: 14,
    ),
    this.timeTextStyle = const TextStyle(
      color: Color(0xff9CA3AF),
      fontSize: 12,
    ),
    this.unreadBadgeColor = const Color(0xff1064FF),
    this.unreadBadgeTextStyle = const TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    this.readIconColor = const Color(0xff1064FF),
    this.unreadIconColor = const Color(0xff9CA3AF),
    this.onlineColor = const Color(0xff22C55E),
    this.dividerColor = const Color(0xffE5E7EB),
    this.showDividers = true,
  });

  final Color backgroundColor;
  final Color avatarBackgroundColor;
  final TextStyle avatarTextStyle;
  final TextStyle titleTextStyle;
  final TextStyle previewTextStyle;
  final TextStyle timeTextStyle;
  final Color unreadBadgeColor;
  final TextStyle unreadBadgeTextStyle;

  /// O'zimiz yuborgan oxirgi xabar o'qilganda ishlatiladigan rang.
  final Color readIconColor;
  final Color unreadIconColor;
  final Color onlineColor;
  final Color dividerColor;
  final bool showDividers;
}

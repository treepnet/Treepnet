part of messenger_chat;

mixin _DateUtility {
  static String getFormattedTime(String date) {
    try {
      final dateTime = DateTime.tryParse(date)?.toLocal();
      if (dateTime == null) return 'Invalid';

      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  /// The heading over a day's messages, by the phone's own clock: "Today",
  /// "Yesterday", "12 October", or "12 October 2025" in another year — month
  /// names in the chat language. (Days used to be cut at UTC midnight, so in
  /// Uzbekistan anything sent 00:00–05:00 landed under the day before, and
  /// months were always English.)
  static String getFormattedDateAndMonth(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    if (day == DateTime(now.year, now.month, now.day)) return _AppTexts.today;
    if (day == DateTime(now.year, now.month, now.day - 1)) {
      return _AppTexts.yesterday;
    }
    final sameYear = local.year == now.year;
    try {
      return DateFormat(
        sameYear ? 'd MMMM' : 'd MMMM y',
        _ChatLocalizations.instance.locale,
      ).format(local);
    } catch (_) {
      // No month names for this language: numbers.
      return DateFormat(sameYear ? 'dd.MM' : 'dd.MM.yyyy').format(local);
    }
  }

  /// Whether [current] and [next] fall on different days, by the phone's clock.
  static bool shouldShowDate(DateTime current, DateTime? next) {
    if (next == null) return true;
    final a = current.toLocal();
    final b = next.toLocal();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  /// When the peer was last seen: the time if it was today, "yesterday
  /// 14:02", "12.10", or "12.10.25" in another year. It used to be the time
  /// alone, so someone gone for days read as seen today.
  static String getFormattedLastSeen(DateTime lastSeen) {
    final local = lastSeen.toLocal();
    final now = DateTime.now();
    final day = DateTime(local.year, local.month, local.day);
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    if (day == DateTime(now.year, now.month, now.day)) return time;
    if (day == DateTime(now.year, now.month, now.day - 1)) {
      return '${_AppTexts.yesterday.toLowerCase()} $time';
    }
    final date = '${two(local.day)}.${two(local.month)}';
    return local.year == now.year ? date : '$date.${two(local.year % 100)}';
  }
}

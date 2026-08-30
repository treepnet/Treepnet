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

  static String getFormattedDateAndMonth(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final inputDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (inputDate == today) {
      return _AppTexts.today;
    } else if (inputDate == yesterday) {
      return _AppTexts.yesterday;
    } else {
      final dateFormat = DateFormat('d MMMM');
      return dateFormat.format(dateTime.toLocal());
    }
  }

  static bool shouldShowDate(DateTime current, DateTime? next) {
    if (next == null) return true;
    final currentDate = DateTime(current.year, current.month, current.day);
    final nextDate = DateTime(next.year, next.month, next.day);
    return currentDate != nextDate;
  }
}

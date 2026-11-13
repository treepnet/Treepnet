/// A story's day as its covers show it: `5.03.2026`, on this phone's
/// calendar.
///
/// The server sends times in UTC, and a story's `createdAt` is read as UTC:
/// formatted as it was, one posted in Uzbekistan (UTC+5) between midnight
/// and 05:00 carried the day before.
String storyShortDate(DateTime at) {
  final local = at.toLocal();
  return '${local.day}.${local.month.toString().padLeft(2, '0')}.'
      '${local.year}';
}

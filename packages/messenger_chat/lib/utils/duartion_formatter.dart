part of messenger_chat;

mixin DurationFormatter {
  static String format(String duration) {
    if (duration.isEmpty) return "0:00";
    if (duration.contains(':')) return duration;

    final secondsDouble = double.tryParse(duration) ?? 0;
    final totalSeconds = secondsDouble.floor();

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "$minutes:${seconds.toString().padLeft(2, '0')}";
    }
  }
}

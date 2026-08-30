// ToastData model for premium notifications.

enum ToastType { error, success, info, warning }

class ToastData {
  final String message;
  final ToastType type;
  final Duration duration;

  ToastData({
    required this.message,
    this.type = ToastType.info,
    this.duration = const Duration(seconds: 3),
  });
}

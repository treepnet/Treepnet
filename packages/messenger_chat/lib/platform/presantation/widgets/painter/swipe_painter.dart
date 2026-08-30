part of messenger_chat;

class _SwipePainter extends CustomPainter {
  _SwipePainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final width = size.width * progress;

    canvas.drawRect(
      Rect.fromLTWH(size.width - width, 0, width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SwipePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

part of messenger_chat;

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.waveform,
    required this.progress,
    required this.color,
  });
  final Float32List? waveform;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform == null) return;
    final data = waveform!;
    const int barCount = 40;
    const double spacing = 1.0;

    final double totalSpacing = spacing * (barCount - 1);
    final double barWidth = (size.width - totalSpacing) / barCount;
    final double centerY = size.height / 2;

    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final paint = Paint()..style = PaintingStyle.fill;
    final double minBarHeight = 4.0;
    final double maxBarHeight = 24.0;
    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + spacing);

      final int dataIndex = ((i / barCount) * data.length).floor().clamp(
            0,
            data.length - 1,
          );
      final double sample = data[dataIndex].clamp(-0.3, 1.0);
      final double normalized = sample.abs().clamp(0.0, 1.0);

      final double dynamicHeight = size.height * normalized * 15;

      // barHeight ni minimal va maksimal chegarada clamp qilish
      final double barHeight = dynamicHeight.clamp(minBarHeight, maxBarHeight);

      final double y = centerY - barHeight / 2;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      paint.color = color.withAlpha(77);
      canvas.drawRRect(barRect, paint);

      final double barStartProgress = i / barCount;
      final double barEndProgress = (i + 1) / barCount;

      if (progress > barStartProgress) {
        final double localProgress = ((progress - barStartProgress) /
                (barEndProgress - barStartProgress))
            .clamp(0.0, 1.0);

        final double filledWidth = barWidth * localProgress;

        paint.color = color;
        final fillRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, filledWidth, barHeight),
          Radius.circular(barWidth / 2),
        );

        canvas.drawRRect(fillRect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.waveform != waveform || oldDelegate.progress != progress;
}

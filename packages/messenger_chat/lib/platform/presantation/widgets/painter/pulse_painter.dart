part of messenger_chat;

class _MicPulsePainter extends CustomPainter {
  _MicPulsePainter({
    required this.scale,
    required this.color,
    required this.time,
  });

  final double scale;
  final Color color;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedScale = scale.clamp(0.0, 1.0);
    if (clampedScale == 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Anchor to the 42px button (radius 21.0)
    const double buttonRadius = 21.0;
    const double maxExpansion = 4.0; // Max 4px beyond button

    // Intensity of wobble (liquid effect)
    final wobbleIntensity = (scale - 1.0).clamp(0.0, 1.0);

    // When idle (scale <= 1.0), shrink slightly to hide under button
    // When active, expand up to buttonRadius + 4.0
    final idleReduction = (1.0 - scale.clamp(0.0, 1.0)) * 3.0;
    final baseRadius = buttonRadius - idleReduction;
    final expansion = (scale - 1.0).clamp(0.0, 1.0) * maxExpansion;

    // We draw 3 layers of "blobs" that float over each other
    for (int i = 0; i < 3; i++) {
      final progress = i / 2; // 0, 0.5, 1.0

      // Balanced rotation and phase for a premium Telegram-like feel
      final layerPhase = (time * 1.5 * math.pi) + (i * 2.0);
      final waveFrequency = (2.0 + i).floorToDouble();
      final rotation = time * (0.4 + i * 0.15) * 2 * math.pi;

      // Radius expands from button-size up to button+4px
      final layerRadius = baseRadius + (expansion * progress);

      // Opacity is very low for that "liquid glow" feel
      final opacity = (0.2 - progress * 0.1) * clampedScale;

      final path = Path();
      const int steps = 180;

      for (int step = 0; step <= steps; step++) {
        final angle = (2 * math.pi * step) / steps;

        // Wobble intensity depends on speaking
        // Wobble amplitude is also small to stay within the 4px limit mostly
        final maxWobble = layerRadius * 0.1 * wobbleIntensity;
        final wobble = math.sin(angle * waveFrequency + layerPhase) * maxWobble;
        final wobble2 = math.cos(angle * 3.0 + layerPhase) * (maxWobble * 0.4);

        final r = layerRadius + wobble + wobble2;

        // Apply rotation
        final rotatedAngle = angle + rotation;
        final x = center.dx + r * math.cos(rotatedAngle);
        final y = center.dy + r * math.sin(rotatedAngle);

        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      paint.color = color.withAlpha((255.0 * opacity).round());
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MicPulsePainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.time != time ||
      oldDelegate.color != color;
}

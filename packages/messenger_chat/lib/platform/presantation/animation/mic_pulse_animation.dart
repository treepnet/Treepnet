part of messenger_chat;

class _MicPulseAnimation extends StatefulWidget {
  const _MicPulseAnimation({
    required this.scale,
    required this.isRecording,
    required this.visible,
    required this.color,
    required this.child,
  });

  final double scale;
  final Color color;
  final bool visible;
  final bool isRecording;
  final Widget child;

  @override
  State<_MicPulseAnimation> createState() => _MicPulseAnimationState();
}

class _MicPulseAnimationState extends State<_MicPulseAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  double _smoothScale = 0.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _smoothScale = widget.scale;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) return widget.child;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              // Smoothly interpolate towards the target scale (lerp)
              // 0.1 is the smoothing factor. Smaller = slower/smoother.
              _smoothScale = lerpDouble(_smoothScale, widget.scale, 0.12)!;

              return OverflowBox(
                maxWidth: 80,
                maxHeight: 80,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: _smoothScale.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _smoothScale,
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MicPulsePainter(
                          scale: _smoothScale,
                          color: widget.color,
                          time: _pulseController.value,
                        ),
                        child: const SizedBox(width: 80, height: 80),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

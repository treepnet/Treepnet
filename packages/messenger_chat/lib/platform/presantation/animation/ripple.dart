part of messenger_chat;

class _RippleEffect extends StatefulWidget {
  const _RippleEffect({
    required this.child,
    required this.onTap,
    required this.rippleColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color rippleColor;

  Duration get duration => const Duration(milliseconds: 250);

  bool get isDisabled => false;

  @override
  State<_RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<_RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Offset? _tapPosition;
  double _rippleRadius = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _animation.addListener(() => setState(() {}));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        _tapPosition = null;
      }
    });
  }

  void _handleTapDown(TapDownDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    _tapPosition = box.globalToLocal(details.globalPosition);

    final size = box.size;
    final dx = _tapPosition!.dx > size.width / 2
        ? _tapPosition!.dx
        : size.width - _tapPosition!.dx;
    final dy = _tapPosition!.dy > size.height / 2
        ? _tapPosition!.dy
        : size.height - _tapPosition!.dy;

    _rippleRadius = math.sqrt(dx * dx + dy * dy);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (details) {
      if (widget.isDisabled) return;

      _handleTapDown(details);
    },
    onTap: () {
      if (widget.isDisabled || widget.onTap == null) return;

      widget.onTap!();
    },
    child: CustomPaint(
      foregroundPainter: _RipplePainter(
        progress: _animation.value,
        tapPosition: _tapPosition,
        rippleRadius: _rippleRadius,
        color: widget.rippleColor,
      ),
      child: widget.child,
    ),
  );
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.tapPosition,
    required this.rippleRadius,
    required this.color,
  });

  final double progress;
  final Offset? tapPosition;
  final double rippleRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (tapPosition == null) return;

    final paint = Paint()
      ..color = color.withAlpha((255.0 * (1 - progress)).round())
      ..style = PaintingStyle.fill;

    canvas.drawCircle(tapPosition!, rippleRadius * progress, paint);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.tapPosition != tapPosition;
}

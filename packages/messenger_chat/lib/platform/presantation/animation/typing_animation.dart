part of messenger_chat;

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.dotColor});

  final Color dotColor;
  final double size = 6;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  final int dotCount = 3;
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  final Duration dotDuration = const Duration(milliseconds: 120);
  final Duration pauseBetweenLoops = const Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      dotCount,
      (index) => AnimationController(vsync: this, duration: dotDuration),
    );

    _animations = _controllers
        .map(
          (controller) =>
              Tween<double>(begin: 0.0, end: -(widget.size)).animate(
                CurvedAnimation(parent: controller, curve: Curves.easeInOut),
              ),
        )
        .toList();

    _startLoop();
  }

  Future<void> _startLoop() async {
    while (mounted) {
      for (int i = 0; i < dotCount; i++) {
        await _controllers[i].forward();
        await _controllers[i].reverse();
      }
      await Future.delayed(pauseBetweenLoops);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      dotCount,
      (index) => AnimatedBuilder(
        animation: _animations[index],
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _animations[index].value),
          child: Container(
            width: widget.size,
            height: widget.size,
            margin: EdgeInsets.symmetric(horizontal: widget.size * (4 / 6)),
            decoration: BoxDecoration(
              color: widget.dotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

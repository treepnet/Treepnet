part of messenger_chat;

class _SlideUpFadeTransition extends StatefulWidget {
  const _SlideUpFadeTransition({required this.child});

  final Widget child;

  Duration get duration => const Duration(milliseconds: 800);

  Curve get curve => Curves.easeOut;

  @override
  State<_SlideUpFadeTransition> createState() => _SlideUpFadeTransitionState();
}

class _SlideUpFadeTransitionState extends State<_SlideUpFadeTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curvedAnimation);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SlideTransition(
    position: _slideAnimation,
    child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
  );
}

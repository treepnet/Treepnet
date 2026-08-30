part of messenger_chat;

class _ChatMessageAnimator extends StatefulWidget {
  const _ChatMessageAnimator({required this.child, this.shouldAnimate = true});

  final Widget child;
  final bool shouldAnimate;
  Duration get duration => const Duration(milliseconds: 300);
  Curve get curve => Curves.easeOut;

  @override
  State<_ChatMessageAnimator> createState() => _ChatMessageAnimatorState();
}

class _ChatMessageAnimatorState extends State<_ChatMessageAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _sizeAnimation;

  bool _visible = true;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: widget.duration, vsync: this);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _sizeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() {
          _visible = false;
        });
      }
    });

    if (widget.shouldAnimate) {
      _visible = true;
      _controller.forward();
    } else {
      _visible = false;
      _controller.reverse(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _ChatMessageAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.shouldAnimate != widget.shouldAnimate) {
      if (widget.shouldAnimate) {
        setState(() {
          _visible = true;
        });
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return SizeTransition(
      sizeFactor: _sizeAnimation,
      axisAlignment: -1.0,
      child: SlideTransition(position: _slideAnimation, child: widget.child),
    );
  }
}

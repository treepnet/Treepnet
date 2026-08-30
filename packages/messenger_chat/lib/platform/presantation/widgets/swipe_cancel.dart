part of messenger_chat;

class SwipeCancel extends StatefulWidget {
  const SwipeCancel({super.key});

  @override
  State<SwipeCancel> createState() => _SwipeCancelState();
}

class _SwipeCancelState extends State<SwipeCancel>
    with SingleTickerProviderStateMixin {
  double _swipeProgress = 0.0;

  double get maxDragDistance => 300;

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      final delta = details.primaryDelta ?? 0.0;
      _swipeProgress += delta / maxDragDistance;
      _swipeProgress = _swipeProgress.clamp(0.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_swipeProgress > 0.5) {
      // Trigger cancel animation
      _controller.forward(from: _swipeProgress).then((_) {
        setState(() {
          _swipeProgress = 1.0;
        });
      });
    } else {
      // Revert back
      _controller.reverse(from: _swipeProgress).then((_) {
        setState(() {
          _swipeProgress = 0.0;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final animatedProgress = _controller.isAnimating
              ? _controller.value
              : _swipeProgress;

          return CustomPaint(
            painter: _SwipePainter(progress: animatedProgress),
            child: Center(
              child: Text(
                animatedProgress == 1.0
                    ? _AppTexts.recordCancel
                    : _AppTexts.swipToLeft,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        },
      ),
    ),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('_maxDragDistance', maxDragDistance));
    properties.add(DoubleProperty('_maxDragDistance', maxDragDistance));
  }
}

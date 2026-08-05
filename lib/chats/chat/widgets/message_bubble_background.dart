import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MessageBubbleBackground extends StatelessWidget {
  const MessageBubbleBackground({required this.colors, super.key, this.child});

  final List<Color> colors;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      isComplex: true,
      painter: BubblePainter(
        scrollable: Scrollable.of(context),
        bubbleContext: context,
        colors: colors,
      ),
      child: child,
    );
  }
}

class BubblePainter extends CustomPainter {
  BubblePainter({
    required ScrollableState scrollable,
    required BuildContext bubbleContext,
    required List<Color> colors,
  }) : _scrollable = scrollable,
       _bubbleContext = bubbleContext,
       _colors = colors,
       super(repaint: scrollable.position);

  final ScrollableState _scrollable;
  final BuildContext _bubbleContext;
  final List<Color> _colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scrollableBox = _scrollable.context.findRenderObject()! as RenderBox;
    final scrollableRect = Offset.zero & scrollableBox.size;
    final bubbleBox = _bubbleContext.findRenderObject()! as RenderBox;

    final origin = bubbleBox.localToGlobal(
      Offset.zero,
      ancestor: scrollableBox,
    );
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        scrollableRect.topCenter,
        scrollableRect.bottomCenter,
        _colors,
        // Stops must match the number of colors. The incoming-bubble colours
        // are a 2-colour list, which used to be paired with a single [1.0]
        // stop — `ui.Gradient.linear` then throws (colors.length !=
        // stops.length), the painter fails, and the incoming bubble renders
        // blank. Only the 4-colour outgoing gradient needs explicit stops;
        // for anything else pass null so the colours distribute evenly.
        _colors.length == 4 ? const [0.0, 0.5, 0.75, 1.0] : null,
        TileMode.clamp,
        Matrix4.translationValues(-origin.dx, -origin.dy, 0).storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) {
    return oldDelegate._scrollable != _scrollable ||
        oldDelegate._bubbleContext != _bubbleContext ||
        oldDelegate._colors != _colors;
  }
}

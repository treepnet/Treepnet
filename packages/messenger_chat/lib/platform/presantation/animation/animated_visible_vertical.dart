part of messenger_chat;

class _AnimatedVisibleVertical extends StatelessWidget {
  const _AnimatedVisibleVertical({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  Duration get duration => const Duration(milliseconds: 200);

  Curve get curve => Curves.easeInOut;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: duration,
    switchInCurve: curve,
    switchOutCurve: curve,
    layoutBuilder: (currentChild, previousChildren) => Stack(
      alignment: Alignment.centerRight,
      children: <Widget>[
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
    ),
    transitionBuilder: (child, animation) {
      final scale = Tween<double>(
        begin: -0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: curve));

      return SizeTransition(
        sizeFactor: animation,
        axis: Axis.vertical,
        axisAlignment: -.5,
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
    child: visible
        ? SizedBox(key: const ValueKey('visible'), child: child)
        : const SizedBox(key: ValueKey('invisible'), width: 0, height: 0),
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Cubic>('curve', curve as Cubic?));
  }
}

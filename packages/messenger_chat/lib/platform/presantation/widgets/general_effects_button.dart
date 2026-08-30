part of messenger_chat;

class _GeneralEffectsButton extends StatelessWidget {
  const _GeneralEffectsButton({
    required this.child,
    required this.onTap,
    required this.constraints,
    this.rippleEffectColor = Colors.blue,
    this.borderRadius,
    super.key,
  });

  final BoxConstraints constraints;
  final VoidCallback onTap;
  final Widget child;
  final Color rippleEffectColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => _ScaleX(
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: constraints,
        child: _RippleEffect(
          onTap: () {
            HapticFeedback.mediumImpact();

            onTap();
          },
          rippleColor: rippleEffectColor,
          child: child,
        ),
      ),
    ),
  );
}

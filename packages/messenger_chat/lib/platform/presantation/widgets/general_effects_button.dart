part of messenger_chat;

class _GeneralEffectsButton extends StatelessWidget {
  const _GeneralEffectsButton({
    required this.child,
    required this.onTap,
    required this.constraints,
    this.rippleEffectColor = const Color(0x1AFFFFFF),
    this.borderRadius,
    this.haptic = false,
    super.key,
  });

  final BoxConstraints constraints;
  final VoidCallback onTap;
  final Widget child;
  final Color rippleEffectColor;
  final BorderRadius? borderRadius;

  /// A light tap felt in the hand — for sending only; every other button in
  /// the chat (emoji, scroll down, back) is silent.
  final bool haptic;

  @override
  Widget build(BuildContext context) => _ScaleX(
    child: ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      clipBehavior: Clip.hardEdge,
      child: ConstrainedBox(
        constraints: constraints,
        child: _RippleEffect(
          onTap: () {
            if (haptic) HapticFeedback.lightImpact();
            onTap();
          },
          rippleColor: rippleEffectColor,
          child: child,
        ),
      ),
    ),
  );
}

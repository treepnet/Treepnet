import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class UserProfileButton extends StatelessWidget {
  const UserProfileButton({
    this.label,
    super.key,
    this.child,
    this.textStyle,
    this.padding,
    this.fadeStrength = FadeStrength.sm,
    this.color,
    this.gradient,
    this.onTap,
  });

  final String? label;
  final Widget? child;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final FadeStrength fadeStrength;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark 
        ? Colors.white.withOpacity(0.04) 
        : Colors.black.withOpacity(0.03);

    final effectiveColor = color ?? defaultBg;
    final effectiveTextStyle = textStyle ?? 
        (gradient != null 
            ? context.labelLarge?.copyWith(color: Colors.white) 
            : context.labelLarge);
    final effectivePadding =
        padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        );

    // Only the default translucent variant gets an outline; solid-colour
    // buttons (Follow white, Message grey) are borderless per the design.
    final border = (color == null && gradient == null)
        ? Border.all(color: AppColors.borderOutline, width: 1.0)
        : null;

    return DefaultTextStyle(
      style: effectiveTextStyle!,
      child: Container(
        decoration: BoxDecoration(
          color: gradient == null ? effectiveColor : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: border,
        ),
        child: Tappable.faded(
          onTap: onTap,
          fadeStrength: fadeStrength,
          borderRadius: BorderRadius.circular(12),
          backgroundColor: Colors.transparent,
          child: Padding(
            padding: effectivePadding,
            child: Align(
              child:
                  child ??
                  Text(
                    label!,
                    style: effectiveTextStyle.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

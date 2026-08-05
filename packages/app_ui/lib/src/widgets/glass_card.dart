import 'dart:ui';
import 'package:flutter/material.dart';

/// {@template glass_card}
/// A premium glassmorphic card container with blur, light border highlights, and shadow.
/// {@endtemplate}
class GlassCard extends StatelessWidget {
  /// {@macro glass_card}
  const GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24.0,
    this.blur = 16.0,
    super.key,
  });

  /// The widget content inside the card.
  final Widget child;

  /// Inner padding of the card.
  final EdgeInsetsGeometry padding;

  /// Border radius of the card.
  final double borderRadius;

  /// Blur intensity.
  final double blur;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor = isDark 
        ? Colors.white.withOpacity(0.04) 
        : Colors.white.withOpacity(0.45);

    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.6);

    final shadowColor = isDark
        ? Colors.black.withOpacity(0.2)
        : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor,
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

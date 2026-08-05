import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

class LikeButton extends StatelessWidget {
  const LikeButton({
    required this.isLiked,
    required this.onLikedTap,
    super.key,
    this.scaleStrength = ScaleStrength.sm,
    this.color,
    this.size,
  });

  final bool isLiked;
  final VoidCallback onLikedTap;
  final Color? color;
  final double? size;
  final ScaleStrength scaleStrength;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      backgroundColor: AppColors.transparent,
      scaleStrength: scaleStrength,
      onTap: onLikedTap,
      // Figma icon set: filled heart once liked, outlined otherwise.
      child: Builder(
        builder: (context) {
          final side = size ?? AppSize.iconSizeMedium;
          final tint = isLiked ? AppColors.pink : (color ?? context.adaptiveColor);
          final icon = isLiked
              ? Assets.icons.heartFilled
              : Assets.icons.heartLined;
          return icon.svg(
            width: side,
            height: side,
            colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
          );
        },
      ),
    );
  }
}

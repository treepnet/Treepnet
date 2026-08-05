import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';

class FollowButton extends StatelessWidget {
  const FollowButton({
    required this.isFollowed,
    required this.follow,
    this.isOutlined = false,
    super.key,
  });

  final bool isFollowed;
  final VoidCallback follow;
  final bool isOutlined;

  String? get _followingStatus {
    if (!isFollowed) return BlockSettings().followTextDelegate.followText;
    return BlockSettings().followTextDelegate.followingText;
  }

  @override
  Widget build(BuildContext context) {
    // Design: "Follow" is a solid white pill with black text; once you follow,
    // it turns #414141 with white text.
    final effectiveBackgroundColor = isFollowed
        ? const Color(0xFF414141)
        : AppColors.white;
    final effectiveTextColor = isFollowed ? AppColors.white : AppColors.black;

    return switch (_followingStatus) {
      null => const SizedBox.shrink(),
      final String data => Tappable.faded(
        onTap: follow,
        borderRadius: BorderRadius.circular(8),
        backgroundColor: effectiveBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Text(
            data,
            style: context.labelLarge?.copyWith(
              color: effectiveTextColor,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
      ),
    };
  }
}

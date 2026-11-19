import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// A tab of a page's header (the feed's Posts and Stories, Trends' Maps and
/// Posts): its label, white once shown, over an underline that grows in.
class TopBarTab extends StatelessWidget {
  const TopBarTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.titleMedium?.copyWith(
              fontSize: 24,
              fontWeight: AppFontWeight.semiBold,
              color: isActive ? AppColors.white : AppColors.textSecondary,
            ),
          ),
          const Gap.v(AppSpacing.xs),
          // The active tab's underline; the inactive one keeps the same space
          // so the labels never shift.
          AnimatedContainer(
            duration: 180.ms,
            height: 2,
            width: isActive ? 66 : 0,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

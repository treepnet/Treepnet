import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/timeline/view/timeline_page.dart'
    show TimelineSearchButton;

/// Trends' header, as the feed's: two centred tabs — Maps (posts on their
/// authors' globes) and Posts (the grid) — the shown one underlined, and the
/// search at the right, where the feed has its bell.
class TrendsTopBar extends StatelessWidget {
  const TrendsTopBar({
    required this.currentTab,
    required this.onTabChanged,
    super.key,
  });

  /// [maps] or [posts].
  final int currentTab;
  final ValueSetter<int> onTabChanged;

  static const maps = 0;
  static const posts = 1;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderOutline),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrendsTab(
                    key: const ValueKey('trendsMapsTab'),
                    label: context.l10n.trendsMapsTabText,
                    isActive: currentTab == maps,
                    onTap: () => onTabChanged(maps),
                  ),
                  const Gap.h(AppSpacing.xlg),
                  _TrendsTab(
                    key: const ValueKey('trendsPostsTab'),
                    label: context.l10n.postsText,
                    isActive: currentTab == posts,
                    onTap: () => onTabChanged(posts),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.centerRight,
              child: TimelineSearchButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tab as the feed's (`_FeedTab` in feed_top_bar.dart): its label, white
/// once shown, over an underline that grows in.
class _TrendsTab extends StatelessWidget {
  const _TrendsTab({
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
          // The shown tab's underline; the other keeps the same space so the
          // labels never shift.
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

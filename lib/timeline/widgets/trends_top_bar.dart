import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/feed/widgets/top_bar_tab.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/timeline/widgets/timeline_search_button.dart';

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
          border: Border(bottom: BorderSide(color: AppColors.borderOutline)),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TopBarTab(
                    key: const ValueKey('trendsMapsTab'),
                    label: context.l10n.trendsMapsTabText,
                    isActive: currentTab == maps,
                    onTap: () => onTabChanged(maps),
                  ),
                  const Gap.h(AppSpacing.xlg),
                  TopBarTab(
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

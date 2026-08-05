import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/notifications/view/notifications_page.dart';
import 'package:user_repository/user_repository.dart';

/// The feed's header from the design: two centered tabs — `Posts` and
/// `Stories` — with the active one underlined, and a notification bell pinned
/// to the right. Replaces the old logo app bar.
class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    required this.currentTab,
    required this.onTabChanged,
    super.key,
  });

  /// 0 = Posts, 1 = Stories.
  final int currentTab;

  final ValueSetter<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 52,
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderOutline, width: 1),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FeedTab(
                    label: context.l10n.postsText,
                    isActive: currentTab == 0,
                    onTap: () => onTabChanged(0),
                  ),
                  const Gap.h(AppSpacing.xlg),
                  _FeedTab(
                    label: context.l10n.storiesText,
                    isActive: currentTab == 1,
                    onTap: () => onTabChanged(1),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Tappable.scaled(
                  onTap: () {
                    // Clear the badge on open. The watermark lives on the
                    // profile row, which the count query joins, so the badge
                    // drops without any extra refresh plumbing.
                    unawaited(
                      context.read<UserRepository>().markNotificationsSeen(
                        userId: context.read<AppBloc>().state.user.id,
                      ),
                    );
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    );
                  },
                  child: const _BellIcon(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
    required this.label,
    required this.isActive,
    required this.onTap,
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

/// The bell with a live unread count, styled like the chat badge in the bottom
/// bar so the two read as the same thing.
///
/// The stream is captured once in [initState]: rebuilding the top bar on every
/// tab change would otherwise re-subscribe on each build.
class _BellIcon extends StatefulWidget {
  const _BellIcon();

  @override
  State<_BellIcon> createState() => _BellIconState();
}

class _BellIconState extends State<_BellIcon> {
  late final Stream<int> _unread;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AppBloc>().state.user.id;
    _unread = context.read<UserRepository>().unreadNotificationsCount(
      userId: userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = Assets.icons.notificationLined.svg(
      width: AppSize.iconSizeMedium,
      height: AppSize.iconSizeMedium,
      colorFilter: ColorFilter.mode(context.adaptiveColor, BlendMode.srcIn),
    );

    return StreamBuilder<int>(
      stream: _unread,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Badge.count(
          count: count,
          isLabelVisible: count > 0,
          backgroundColor: AppColors.white,
          textColor: AppColors.black,
          child: icon,
        );
      },
    );
  }
}

import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed_mode.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:treepnet/notifications/view/notifications_page.dart';
import 'package:user_repository/user_repository.dart';

/// The feed's header from the design: two centered tabs — `Posts` and
/// `Stories` — with the active one underlined, a notification bell pinned
/// to the right and, on Posts only, the switch between the usual feed and
/// the new one pinned to the left. Replaces the old logo app bar.
class FeedTopBar extends StatelessWidget {
  const FeedTopBar({
    required this.currentTab,
    required this.onTabChanged,
    this.feedMode = FeedMode.classic,
    this.onFeedModeChanged,
    super.key,
  });

  /// 0 = Posts, 1 = Stories.
  final int currentTab;

  final ValueSetter<int> onTabChanged;

  /// The feed the Posts tab shows, and where a pick on the switch goes.
  final FeedMode feedMode;
  final ValueSetter<FeedMode>? onFeedModeChanged;

  /// The bell's and the switch's sides: the same width, so the tabs stay in
  /// the middle whichever shows.
  static const double _side = 78;

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
        child: Row(
          children: [
            SizedBox(
              width: _side,
              child: currentTab == 0 && onFeedModeChanged != null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.md),
                        child: FeedModeSwitch(
                          mode: feedMode,
                          onChanged: onFeedModeChanged!,
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              // A narrow phone shrinks the tabs a little rather than let them
              // run under the switch or the bell.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
              ),
            ),
            SizedBox(
              width: _side,
              child: Align(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The switch at the feed's top left: the new feed (the profile's globe) or
/// the usual one (the profile's grid), the picked side white with a black
/// icon, as the app's white buttons.
class FeedModeSwitch extends StatelessWidget {
  const FeedModeSwitch({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final FeedMode mode;
  final ValueSetter<FeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.inputSpace,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeedModeSide(
            icon: Assets.icons.globusLined,
            label: l10n.feedModeNewText,
            selected: mode == FeedMode.globe,
            onTap: () => onChanged(FeedMode.globe),
          ),
          _FeedModeSide(
            icon: Assets.icons.postsLined,
            label: l10n.feedModeClassicText,
            selected: mode == FeedMode.classic,
            onTap: () => onChanged(FeedMode.classic),
          ),
        ],
      ),
    );
  }
}

class _FeedModeSide extends StatelessWidget {
  const _FeedModeSide({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final SvgGenImage icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tappable.scaled(
        onTap: selected ? null : onTap,
        child: AnimatedContainer(
          duration: 180.ms,
          width: 30,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.white : AppColors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: icon.svg(
            width: 16,
            height: 16,
            colorFilter: ColorFilter.mode(
              selected ? AppColors.black : AppColors.textSecondary,
              BlendMode.srcIn,
            ),
          ),
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

    // Notifications turned off on the phone count as one: the list then
    // starts with the way to turn them on, and the 1 goes once they are.
    return ValueListenableBuilder<bool?>(
      valueListenable: PushNotifications.allowed,
      builder: (context, allowed, _) => StreamBuilder<int>(
        stream: _unread,
        builder: (context, snapshot) {
          final count = (snapshot.data ?? 0) + (allowed == false ? 1 : 0);
          return Badge.count(
            count: count,
            isLabelVisible: count > 0,
            backgroundColor: AppColors.white,
            textColor: AppColors.black,
            child: icon,
          );
        },
      ),
    );
  }
}

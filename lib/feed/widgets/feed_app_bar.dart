import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/notifications/view/notifications_page.dart';

class FeedAppBar extends StatelessWidget {
  const FeedAppBar({required this.innerBoxIsScrolled, super.key});

  final bool innerBoxIsScrolled;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      sliver: SliverAppBar(
        centerTitle: false,
        forceElevated: innerBoxIsScrolled,
        title: const AppLogo(),
        floating: true,
        snap: true,
        actions: [
          // Chat now lives in the bottom nav, so this opens Notifications.
          Tappable.scaled(
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: AppSize.iconSizeMedium,
              color: context.adaptiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

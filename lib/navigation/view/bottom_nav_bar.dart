import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/home/home.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:go_router/go_router.dart';

/// {@template main_bottom_navigation_bar}
/// Bottom navigation bar of the application. It contains the [navigationShell]
/// that will handle the navigation between the different bottom navigation
/// bars.
/// {@endtemplate}
class BottomNavBar extends StatelessWidget {
  /// {@macro bottom_nav_bar}
  const BottomNavBar({required this.navigationShell, super.key});

  /// Navigation shell that will handle the navigation between the different
  /// bottom navigation bars.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final videoPlayer = VideoPlayerInheritedWidget.of(context);

    final navigationBarItems = mainNavigationBarItems(
      isSelected: (index) => navigationShell.currentIndex == index,
      homeLabel: context.l10n.homeNavBarItemLabel,
      searchLabel: context.l10n.searchNavBarItemLabel,
      createMediaLabel: context.l10n.createMediaNavBarItemLabel,
      reelsLabel: context.l10n.reelsNavBarItemLabel,
      userProfileLabel: context.l10n.profileNavBarItemLabel,
      // Always the Figma glyph — lined, filled while the profile tab is the
      // active one. It used to swap in the user's own avatar once they had
      // one, which left this the only tab in the bar not drawn as an icon.
      userProfileAvatar:
          (navigationShell.currentIndex == 4
                  ? Assets.icons.profileFilled
                  : Assets.icons.profileLined)
              .svg(width: 24, height: 24),
    );

    return DecoratedBox(
      // Foreground: the nav bar's opaque background would otherwise paint over
      // a background-positioned border and hide it.
      position: DecorationPosition.foreground,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderOutline, width: 1),
        ),
      ),
      child: BottomNavigationBar(
      currentIndex: navigationShell.currentIndex,
      onTap: (index) {
        // Never enable the swipe for the feed — it swipes its own tabs now.
        HomeProvider().togglePageView(enable: false);
        if ([0, 1, 2, 3].contains(index)) {
          if (index case 0) videoPlayer.videoPlayerState.playFeed();
          if (index case 1) videoPlayer.videoPlayerState.playTimeline();
          if (index case 2) {
            // New post: jump to the camera page programmatically, but keep the
            // swipe DISABLED. Enabling it let a horizontal drag on New post
            // slide over to the profile/feed page. Back still returns via the
            // PopScope's animateToPage(1), so no swipe is needed here.
            HomeProvider().animateToPage(0);
          }
          // Tab 3 is now Chat (no video) — make sure any player is stopped.
          if (index case 3) videoPlayer.videoPlayerState.stopAll();
        } else {
          videoPlayer.videoPlayerState.stopAll();
        }
        if (index != 2) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        }
        if (index == 0) {
          if (!(index == navigationShell.currentIndex)) return;
          FeedPageController().scrollToTop();
        }
      },
      // The Figma icons are drawn at their native 24x24.
      iconSize: 24,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: navigationBarItems
          .asMap()
          .entries
          .map(
            (entry) => BottomNavigationBarItem(
              // The Chat tab (index 3) shows an unread-messages count badge.
              icon: entry.key == 3
                  ? _ChatTabIcon(
                      child: entry.value.child ?? Icon(entry.value.icon),
                    )
                  : entry.value.child ?? Icon(entry.value.icon),
              label: entry.value.label,
              tooltip: entry.value.tooltip,
            ),
          )
          .toList(),
      ),
    );
  }
}

/// The Chat tab icon with a live unread-messages badge.
///
/// Also the app-wide trigger that starts the chat session right after login:
/// the nav bar is present whenever the user is authenticated, so starting here
/// connects the socket and warms the conversation list so the badge is live
/// even before the inbox is first opened.
class _ChatTabIcon extends StatefulWidget {
  const _ChatTabIcon({required this.child});

  final Widget child;

  @override
  State<_ChatTabIcon> createState() => _ChatTabIconState();
}

class _ChatTabIconState extends State<_ChatTabIcon> {
  @override
  void initState() {
    super.initState();
    final me = context.read<AppBloc>().state.user;
    if (!me.isAnonymous) {
      unawaited(
        ChatSession.instance.ensureStarted(
          myUuid: me.id,
          myName: me.displayUsername,
          myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatSession.instance.unreadTotal,
      builder: (context, count, _) => Badge.count(
        count: count,
        isLabelVisible: count > 0,
        // White pill, black number — the default red-on-white badge was the
        // only saturated colour left in the bar.
        backgroundColor: AppColors.white,
        textColor: AppColors.black,
        child: widget.child,
      ),
    );
  }
}

import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/home/home.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/navigation/tab_reselect.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:user_repository/user_repository.dart';

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
    // The Chat tab (index 3) shows an unread-messages count badge.
    final icons = [
      for (final (index, item) in navigationBarItems.indexed)
        index == 3
            ? _ChatTabIcon(child: item.child ?? Icon(item.icon))
            : item.child ?? Icon(item.icon),
    ];
    // iOS 26/27's floating Liquid Glass capsule, icons only as before. The
    // tab pages run on underneath it (see NavBarInset).
    return _ChatSessionStarter(
      child: Padding(
        padding: EdgeInsets.only(bottom: _aboveSystemButtons(context)),
        child: GlassTabBar.bottom(
          selectedIndex: navigationShell.currentIndex,
          onTabSelected: (index) => _onTap(context, index),
          tabs: [
            for (final (index, icon) in icons.indexed)
              GlassTab(
                icon: icon,
                semanticLabel: navigationBarItems[index].label,
              ),
          ],
        ),
      ),
    );
  }

  /// The glass bar always keeps 20 below its capsule and, unlike the
  /// Material bar it replaced, leaves no room for the system's own bar. That
  /// is right for iOS's home indicator and Android's gesture handle, which
  /// the capsule sits just above. Android 15+ draws the app under its
  /// navigation bar, though, and the three-button one (◁ ○ □) is ~48 tall:
  /// the capsule's lower half went under the buttons. Lifted clear of them,
  /// with a small gap.
  static double _aboveSystemButtons(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return 0;
    final system = MediaQuery.viewPaddingOf(context).bottom;
    // A gesture handle's inset is well under this; button bars are 40+.
    if (system < _buttonBarMinHeight) return 0;
    return system - _glassBottomGap + _gapAboveButtons;
  }

  static const double _buttonBarMinHeight = 32;

  /// GlassTabBar.bottom's default verticalPadding, below the capsule.
  static const double _glassBottomGap = 20;

  static const double _gapAboveButtons = 6;

  void _onTap(BuildContext context, int index) {
    final videoPlayer = VideoPlayerInheritedWidget.of(context);
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
    } else if (index != 2 && index == navigationShell.currentIndex) {
      // Trends, Chat and the profile go back to their top too.
      TabReselect.tapped(index);
    }
  }
}

/// Starts the chat session right after login, once.
///
/// The bar is present whenever the user is signed in, so starting here
/// connects the socket and warms the conversation list, and the Chat tab's
/// badge is live before the inbox is first opened. It used to be the badge's
/// own job, but the glass bar builds each icon twice (again in the lens over
/// the selected tab, which comes and goes as the selection moves): every new
/// copy looked the user's name up and asked again.
class _ChatSessionStarter extends StatefulWidget {
  const _ChatSessionStarter({required this.child});

  final Widget child;

  @override
  State<_ChatSessionStarter> createState() => _ChatSessionStarterState();
}

class _ChatSessionStarterState extends State<_ChatSessionStarter> {
  @override
  void initState() {
    super.initState();
    final me = context.read<AppBloc>().state.user;
    if (!me.isAnonymous) {
      final repo = context.read<UserRepository>();
      unawaited(
        currentChatName(repo, me)
            .then(
              (name) => ChatSession.instance.ensureStarted(
                myUuid: me.id,
                myName: name,
                myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
              ),
            )
            // Offline at launch: the session retries on its own.
            .catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The Chat tab icon with a live unread-messages badge.
class _ChatTabIcon extends StatelessWidget {
  const _ChatTabIcon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatSession.instance.unreadTotal,
      // Badge.count stops at 999+; a tab badge reads better at 99+.
      builder: (context, count, _) => Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        isLabelVisible: count > 0,
        // White pill, black number — the default red-on-white badge was the
        // only saturated colour left in the bar.
        backgroundColor: AppColors.white,
        textColor: AppColors.black,
        child: child,
      ),
    );
  }
}

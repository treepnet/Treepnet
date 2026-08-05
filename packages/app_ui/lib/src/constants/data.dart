// ignore_for_file: public_member_api_docs
import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Navigation bar items
List<NavBarItem> mainNavigationBarItems({
  required String homeLabel,
  required String searchLabel,
  required String createMediaLabel,
  required String reelsLabel,
  required String userProfileLabel,
  required Widget userProfileAvatar,
  required bool Function(int index) isSelected,
}) => <NavBarItem>[
  // The Figma nav icons at their designed 24x24: lined while idle, filled once
  // the tab is the active one.
  NavBarItem(
    child: _navIcon(
      isSelected(0),
      Assets.icons.navHomeLined,
      Assets.icons.navHomeFilled,
    ),
    label: homeLabel,
  ),
  // The 2nd tab is the trends/explore grid — a flame, not a magnifier (that
  // page has its own search bar on top).
  NavBarItem(
    child: _navIcon(
      isSelected(1),
      Assets.icons.navTrendsLined,
      Assets.icons.navTrendsFilled,
    ),
    label: searchLabel,
  ),
  NavBarItem(
    child: _navIcon(
      isSelected(2),
      Assets.icons.navPostLined,
      Assets.icons.navPostFilled,
    ),
    label: createMediaLabel,
  ),
  // The 4th tab is Chat (video/reels removed) — a paper-plane.
  NavBarItem(
    child: _navIcon(
      isSelected(3),
      Assets.icons.navChatLined,
      Assets.icons.navChatFilled,
    ),
    label: reelsLabel,
  ),
  NavBarItem(child: userProfileAvatar, label: userProfileLabel),
];

/// One navigation icon: [filled] when its tab is selected, [lined] otherwise.
Widget _navIcon(bool selected, SvgGenImage lined, SvgGenImage filled) =>
    (selected ? filled : lined).svg(width: 24, height: 24);

class NavBarItem {
  NavBarItem({
    this.icon,
    this.label,
    this.child,
  });

  final String? label;
  final Widget? child;
  final IconData? icon;

  String? get tooltip => label;
}

class GradientColor {
  const GradientColor({required this.hex, this.opacity});

  final String hex;
  final double? opacity;
}

enum PremiumGradient {
  fl0(
    colors: [
      GradientColor(hex: '842CD7'),
      GradientColor(hex: '21F5F1', opacity: .8),
    ],
    stops: [0, 1],
  ),
  telegram(
    colors: [
      GradientColor(hex: '6C93FF'),
      GradientColor(hex: '976FFF'),
      GradientColor(hex: 'DF69D1'),
    ],
    stops: [0, .5, 1],
  );

  const PremiumGradient({
    required this.colors,
    required this.stops,
  });

  final List<GradientColor> colors;
  final List<double> stops;
}

List<String> get commentEmojies => [
  '🩷',
  '🙌',
  '🔥',
  '👏🏻',
  '😢',
  '😍',
  '😮',
  '😂',
];

List<ModalOption> createMediaModalOptions({
  required String reelLabel,
  required String postLabel,
  required String storyLabel,
  required BuildContext context,
  required void Function(String route, {Object? extra}) goTo,
  required bool enableStory,
  ValueSetter<String>? onStoryCreated,
}) => <ModalOption>[
  ModalOption(
    name: reelLabel,
    iconData: Icons.video_collection_outlined,
    onTap: () => goTo('create-post', extra: true),
  ),
  ModalOption(
    name: postLabel,
    iconData: Icons.outbox_outlined,
    onTap: () => goTo('create-post'),
  ),
  if (enableStory)
    ModalOption(
      name: storyLabel,
      iconData: Icons.cameraswitch_outlined,
      onTap: () => goTo('create-stories', extra: onStoryCreated),
    ),
];

List<ModalOption> followerModalOptions({
  required String unfollowLabel,
  required VoidCallback onUnfollowTap,
}) => <ModalOption>[ModalOption(name: unfollowLabel, onTap: onUnfollowTap)];

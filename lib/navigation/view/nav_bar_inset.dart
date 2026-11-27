import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// The bottom bar is iOS 26/27's floating Liquid Glass capsule
/// (liquid_glass_widgets): the tab pages run on underneath it, seen through
/// the glass. These two calls set the glass up; [bootstrap] makes them.
abstract final class LiquidGlassSetup {
  /// Loads the glass shaders before the first frame, so the bar never shows
  /// an unshaded frame.
  static Future<void> initialize() => LiquidGlassWidgets.initialize();

  /// The app, inside what the glass widgets need. The app is a
  /// `MaterialApp`, so the glass follows its theme, not the phone's.
  static Widget wrap(Widget app) => LiquidGlassWidgets.wrap(
    child: app,
    brightnessResolver: Theme.maybeBrightnessOf,
  );
}

/// How much of the bottom of a tab page the floating bottom bar covers.
///
/// The tab pages run on under the bar, with no bottom inset of their own, so
/// the glass has them behind it. Each page leaves this much room after its
/// last row (a list's end, a grid's end, a button pinned to the bottom), so
/// nothing ends up behind the bar for good. Zero anywhere outside the tabs:
/// pages pushed over them have no bar.
class NavBarInset extends InheritedWidget {
  const NavBarInset({required this.height, required super.child, super.key});

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(NavBarInset oldWidget) =>
      height != oldWidget.height;
}

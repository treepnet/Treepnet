import 'package:app_ui/src/colors/app_colors.dart';
import 'package:flutter/material.dart';

/// {@template treepnet_ambient_background}
/// Page shell painting the design's flat background colour behind its child.
/// {@endtemplate}
class TreepNetAmbientBackground extends StatelessWidget {
  /// {@macro treepnet_ambient_background}
  const TreepNetAmbientBackground({
    required this.child,
    super.key,
  });

  /// The child widget to render on top of the ambient background.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The design calls for one flat page colour, so the glow spheres, backdrop
    // blur and grid overlay this used to draw are gone. The widget itself
    // stays because ~20 pages wrap their content in it.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
    );
  }
}

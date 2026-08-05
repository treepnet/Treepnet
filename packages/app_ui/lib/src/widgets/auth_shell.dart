import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Shared layout for the auth screens: the screen's [child] (inputs, buttons,
/// copy) sits centred in the space at the top, and the [AuthBrand] — logo and
/// "Treepnet beta" — is pinned to the very bottom, identical on every screen.
///
/// Scroll-safe: the column is forced to at least the viewport height so the
/// brand stays at the bottom, and everything scrolls when the keyboard is up.
class AuthShell extends StatelessWidget {
  /// {@macro auth_shell}
  const AuthShell({required this.child, this.padding, super.key});

  /// The screen-specific content shown above the brand.
  final Widget child;

  /// Padding around the scrollable area.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.xlg,
                vertical: AppSpacing.md,
              ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                // stretch (not Center) keeps the content full width; Center
                // would collapse a stretch Column to its widest child.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  child,
                  const Spacer(),
                  const AuthBrand(),
                  // Brand lifted ~20px off the bottom edge.
                  const Gap.v(AppSpacing.md + 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

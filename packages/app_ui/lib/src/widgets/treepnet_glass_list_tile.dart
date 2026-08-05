import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// {@template treepnet_glass_list_tile}
/// A reusable glassmorphism-styled list tile.
///
/// It covers two shapes with one look:
///  - the settings shape — an [icon] and a text [label], optionally a [trailing]
///    widget and an accent [showDot];
///  - the richer shape — a [leading] widget (e.g. an avatar) with a [title] and
///    [subtitle], as the chat inbox uses.
///
/// Give it either a [label] or a [title]; the rest is optional.
/// {@endtemplate}
class TreepNetGlassListTile extends StatelessWidget {
  /// {@macro treepnet_glass_list_tile}
  const TreepNetGlassListTile({
    required this.onTap,
    this.label,
    this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onLongPress,
    this.padding,
    this.showDot = false,
    this.accentColor = AppColors.white,
    super.key,
  }) : assert(
         label != null || title != null,
         'Provide either a label (settings row) or a title (rich row).',
       );

  /// The leading icon, if any. Ignored when [leading] is given.
  final IconData? icon;

  /// A leading widget (an avatar, say). Takes precedence over [icon].
  final Widget? leading;

  /// The main text, for the settings shape.
  final String? label;

  /// The primary line, for the rich shape. Takes precedence over [label].
  final Widget? title;

  /// The secondary line under [title].
  final Widget? subtitle;

  /// Callback when tapped.
  final VoidCallback onTap;

  /// Callback when long-pressed (the chat inbox deletes on this).
  final VoidCallback? onLongPress;

  /// Overrides the default inner padding.
  final EdgeInsetsGeometry? padding;

  /// Whether to show an accent dot next to the text.
  final bool showDot;

  /// The accent color used for the dot.
  final Color accentColor;

  /// Optional trailing widget.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final leadingWidget =
        leading ??
        (icon != null
            ? Icon(icon, color: context.colorScheme.onSurface, size: 24)
            : null);

    final content =
        title ??
        Text(
          label!,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        );

    return Material(
      color: AppColors.glassBackground,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
          child: Row(
            children: [
              if (leadingWidget != null) ...[
                leadingWidget,
                const Gap.h(AppSpacing.md),
              ],
              Expanded(
                child: subtitle == null
                    ? content
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          content,
                          const Gap.v(AppSpacing.xxs),
                          subtitle!,
                        ],
                      ),
              ),
              if (showDot)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Trends' search: the magnifier at the top right, where the feed has its
/// bell (the same size and margin), opening the search page as the field on
/// top used to.
class TimelineSearchButton extends StatelessWidget {
  const TimelineSearchButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Semantics(
        button: true,
        label: context.l10n.searchText,
        child: Tappable.scaled(
          onTap: () => context.pushNamed(AppRoutes.search.name),
          child: Assets.icons.search.svg(
            width: AppSize.iconSizeMedium,
            height: AppSize.iconSizeMedium,
            colorFilter: ColorFilter.mode(
              context.adaptiveColor,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/l10n/l10n.dart';

/// "Couldn't load" with a Retry, for a screen whose content failed to load
/// (offline, a server error). Such screens showed what an empty answer would
/// have meant ("No likes yet", "No post found").
class LoadFailed extends StatelessWidget {
  const LoadFailed({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const Gap.v(AppSpacing.md),
            Text(
              context.l10n.couldNotLoadText,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Gap.v(AppSpacing.md),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.retryText),
            ),
          ],
        ),
      ),
    );
  }
}

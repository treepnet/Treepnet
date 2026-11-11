import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:treepnet/l10n/l10n.dart';

/// The end of a list of posts whose next page couldn't be loaded (offline, a
/// timeout): a short note and Retry. Before it, the list just ended there, as
/// if there were no more posts.
///
/// After a tap it shows a spinner until the list rebuilds with the answer.
class PageLoadRetry extends StatefulWidget {
  const PageLoadRetry({required this.onRetry, super.key});

  /// Asks for the same page again.
  final VoidCallback onRetry;

  @override
  State<PageLoadRetry> createState() => _PageLoadRetryState();
}

class _PageLoadRetryState extends State<PageLoadRetry> {
  var _retrying = false;

  @override
  void didUpdateWidget(covariant PageLoadRetry oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The list rebuilt: the retry has its answer.
    _retrying = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_retrying) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.couldNotLoadMorePostsText,
            textAlign: TextAlign.center,
            style: context.bodyMedium,
          ),
          const Gap.v(AppSpacing.sm),
          Tappable.scaled(
            onTap: () {
              setState(() => _retrying = true);
              widget.onRetry();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: Border.all(color: AppColors.borderOutline),
              ),
              child: Text(context.l10n.retryText, style: context.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

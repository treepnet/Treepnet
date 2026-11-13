import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Asks before unfollowing [username] — the sheet with "Unfollow" the
/// profile page always showed — and runs [onUnfollow] if confirmed. For a
/// [isPrivate] account it also says what that costs: its posts again only
/// after a new request is accepted.
///
/// The followers / following lists, notifications and story viewers
/// unfollowed on a single tap of "Following", with no question.
Future<void> confirmUnfollow(
  BuildContext context, {
  required String username,
  required bool isPrivate,
  required VoidCallback onUnfollow,
}) async {
  final l10n = context.l10n;
  final option = await context.showListOptionsModal(
    title: username,
    options: [
      ModalOption(
        name: l10n.cancelFollowingText,
        onTap: onUnfollow,
        // A second question, with the warning, for a private account.
        distractive: isPrivate,
        actionTitle: l10n.unfollowPrivateTitle(username),
        actionContent: l10n.unfollowPrivateText,
        actionYesText: l10n.cancelFollowingText,
        actionNoText: l10n.cancelText,
      ),
    ],
  );
  if (option == null || !context.mounted) return;
  option.onTap(context);
}

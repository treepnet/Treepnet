import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Signs out — but first lets local changes that haven't reached the server
/// (an offline like, comment, follow or profile edit) upload for a few
/// seconds; if some are still left, says how many would be lost and lets the
/// person stay. Signing out wipes the local database with its upload queue,
/// and they used to vanish without a word.
///
/// [context] must outlive the call (a page, or the root navigator's).
Future<void> logOutSafely(BuildContext context) async {
  final appBloc = context.read<AppBloc>();
  final powerSync = context.read<PowerSyncRepository>();

  var pending = await _pending(powerSync);
  if (pending > 0) {
    toggleLoadingIndeterminate();
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (pending > 0 && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      pending = await _pending(powerSync);
    }
    toggleLoadingIndeterminate(enable: false);
  }

  if (pending > 0) {
    if (!context.mounted) return;
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.logOutText),
        content: Text(l10n.logOutUnsavedChangesText(pending)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.logOutAnywayText),
          ),
        ],
      ),
    );
    if (leave != true) return;
  }
  appBloc.add(const AppLogoutRequested());
}

/// 0 when the count can't be read: signing out mustn't get stuck on it.
Future<int> _pending(PowerSyncRepository powerSync) async {
  try {
    return await powerSync.pendingUploads();
  } catch (_) {
    return 0;
  }
}

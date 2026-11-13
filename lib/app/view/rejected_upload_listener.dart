import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powersync_repository/powersync_repository.dart'
    show PowerSyncRepository, RejectedUpload, StuckUpload;
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/monitoring/crash_reporter.dart';

/// Invisible widget that surfaces local changes the server refused for good.
///
/// The sync layer drops such a change — retrying can't help — so without this
/// a post, comment, like or profile edit just vanished on the next sync and
/// nobody knew. Each drop is reported to the crash logger (no content; see
/// [RejectedUpload]) and the user is told it wasn't saved.
///
/// Also reported, without a word to the user: an upload queue stuck on one
/// change ([StuckUpload]; everything after it waits), and a local database
/// that couldn't be opened and was rebuilt, losing what hadn't been sent.
class RejectedUploadListener extends StatefulWidget {
  const RejectedUploadListener({super.key});

  @override
  State<RejectedUploadListener> createState() => _RejectedUploadListenerState();
}

class _RejectedUploadListenerState extends State<RejectedUploadListener> {
  /// One notice is enough when several changes fail together, or one keeps
  /// failing (the presence heartbeat writes every 45 s).
  static const _noticeGap = Duration(seconds: 30);

  StreamSubscription<RejectedUpload>? _subscription;
  StreamSubscription<StuckUpload>? _stuckSubscription;
  DateTime? _lastNotice;

  @override
  void initState() {
    super.initState();
    final repository = context.read<PowerSyncRepository>();
    _subscription = repository.rejectedUploads.listen(_onRejected);
    _stuckSubscription = repository.stuckUploads.listen(
      (stuck) => CrashReporter.instance.report(
        stuck,
        StackTrace.current,
        kind: 'sync-stuck',
      ),
    );
    final wipe = repository.databaseWipe;
    if (wipe != null) {
      CrashReporter.instance.report(wipe, StackTrace.current, kind: 'db-wipe');
    }
  }

  void _onRejected(RejectedUpload rejected) {
    CrashReporter.instance.report(
      rejected,
      StackTrace.current,
      kind: 'sync-rejected',
    );
    final now = DateTime.now();
    final last = _lastNotice;
    if (last != null && now.difference(last) < _noticeGap) return;
    _lastNotice = now;
    if (!mounted) return;
    openSnackbar(SnackbarMessage.error(title: context.l10n.changeNotSavedText));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_stuckSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

import 'package:flutter/foundation.dart';
import 'package:treepnet/monitoring/crash_reporter.dart';

/// Chat failures worth seeing from the field, sent to the crash logger
/// (Telegram): a message the server refused or never confirmed while
/// connected, an inbox or history page that would not load, a token the
/// server keeps refusing. They used to be swallowed, so a chat outage reached
/// no one.
///
/// Expected outcomes — offline, timeouts, gateway hiccups — are dropped, and
/// each kind goes at most once every [gap] from this device, so an outage
/// sends one line per phone, not one per retry.
abstract final class ChatFailures {
  static const gap = Duration(minutes: 10);

  static final _lastSent = <String, DateTime>{};

  /// Where reports go; a test replaces it.
  @visibleForTesting
  static void Function(Object error, StackTrace stack, String kind) sink =
      (error, stack, kind) =>
          CrashReporter.instance.report(error, stack, kind: kind);

  /// Clock for the [gap]; a test replaces it.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  @visibleForTesting
  static void reset() => _lastSent.clear();

  /// Reports [cause] as a chat failure of [kind] (e.g. `inbox`, `dm.send`).
  static void report(String kind, Object cause, [StackTrace? stack]) {
    if (CrashReporter.instance.isExpectedFailure(cause)) return;
    final at = now();
    final last = _lastSent[kind];
    if (last != null && at.difference(last) < gap) return;
    _lastSent[kind] = at;
    sink(ChatFailure(kind, cause), stack ?? StackTrace.current, 'chat-$kind');
  }

  /// Runs [load]; a failure is reported as [kind] and passed on unchanged.
  static Future<T> watch<T>(String kind, Future<T> Function() load) async {
    try {
      return await load();
    } catch (error, stack) {
      report(kind, error, stack);
      rethrow;
    }
  }
}

/// What [ChatFailures] sends: the step that failed and why.
class ChatFailure implements Exception {
  const ChatFailure(this.kind, this.cause);

  final String kind;
  final Object cause;

  @override
  String toString() => 'Chat $kind failed: $cause';
}

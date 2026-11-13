import 'package:postgrest/postgrest.dart';

/// Whether the server refused an upload for good: the same request can't
/// succeed later, so the change is dropped (and the app told) instead of
/// being retried.
///
/// Only 22xxx, 23xxx and 42501 used to count. Anything else was retried
/// forever, and the upload queue goes in order: one such change (a column or
/// table the server no longer has, a trigger refusing, a body over the
/// proxy's 2 MB) held every later post, like and comment on the phone, with
/// no message and no report.
///
/// Still retried: the network, the server being down or overloaded (5xx,
/// PGRST0xx), the token (401, 403, PGRST3xx), 408, 429, and Postgres' own
/// transient ones (deadlock, serialization, statement timeout — see
/// [UploadAttempts] for a timeout that keeps happening).
bool isPermanentUploadError(PostgrestException e) {
  final code = e.code;
  if (code == null) return false;
  // SQLSTATE: bad data (22), a broken rule such as unique, foreign key or
  // check (23), a permission, or a table, column or function that isn't there
  // (42), or a trigger refusing the row (P0001).
  if (RegExp(r'^(22|23|42)[0-9A-Z]{3}$').hasMatch(code)) return true;
  if (code == 'P0001') return true;
  // PostgREST: a request it can't take (PGRST1xx) or a table, column or
  // function its schema doesn't have (PGRST2xx).
  if (RegExp(r'^PGRST[12][0-9]{2}$').hasMatch(code)) return true;
  // A bare HTTP status: the body wasn't PostgREST's (the proxy's, such as 413
  // for a body that's too big). A client error is final, but for those that
  // pass: a token (401, 403), a timeout (408), slow down (429).
  final status = int.tryParse(code);
  if (status != null && status >= 400 && status < 500) {
    return !const {401, 403, 408, 429}.contains(status);
  }
  return false;
}

/// How many times in a row the upload queue's first transaction has failed.
///
/// After [stuckAfter] tries the app hears of it once (it reports it): a queue
/// stuck for minutes means nothing the user does reaches the server. A
/// statement that hit the time limit that many times won't stop doing so, and
/// is dropped then.
class UploadAttempts {
  /// Creates an [UploadAttempts].
  UploadAttempts({this.stuckAfter = 30});

  /// Failures in a row after which the queue counts as stuck.
  final int stuckAfter;

  int? _transaction;
  int _count = 0;

  /// Counts a failure of [transactionId]; returns how many in a row.
  int failed(int? transactionId) {
    if (transactionId != _transaction) {
      _transaction = transactionId;
      _count = 0;
    }
    return ++_count;
  }

  /// The transaction went through, or was dropped.
  void done() {
    _transaction = null;
    _count = 0;
  }

  /// Whether a failure with [code], the [attempt]th in a row, ends the tries.
  bool givesUp(String? code, int attempt) =>
      code == '57014' && attempt >= stuckAfter;
}

/// The upload queue has been failing on the same change for a while
/// ([UploadAttempts.stuckAfter] tries): everything after it waits. Nothing is
/// dropped; the app reports it. Carries no row content.
class StuckUpload {
  /// Creates a [StuckUpload].
  const StuckUpload({
    required this.table,
    required this.op,
    required this.error,
    required this.attempts,
  });

  /// The table of the change it is stuck on.
  final String table;

  /// `put`, `patch` or `delete`.
  final String op;

  /// The error code (or, off the network, the error's type).
  final String error;

  /// Failures in a row so far.
  final int attempts;

  @override
  String toString() =>
      'Upload queue stuck: $op on $table failed $attempts times in a row '
      '($error); every later change waits behind it';
}

/// The phone's database couldn't be opened, so it was deleted and built anew:
/// whatever hadn't reached the server went with it. The app reports it.
class DatabaseWipe {
  /// Creates a [DatabaseWipe].
  const DatabaseWipe({required this.error, required this.pendingChanges});

  /// Why it couldn't be opened.
  final String error;

  /// Changes that hadn't been uploaded, if they could be counted.
  final int? pendingChanges;

  @override
  String toString() =>
      'Local database could not be opened and was rebuilt ($error); '
      '${pendingChanges ?? 'an unknown number of'} unsent change(s) lost';
}

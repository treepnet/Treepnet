import 'dart:async';

import 'package:powersync/powersync.dart';

/// Data the phone syncs only while a screen needs it — someone's profile, a
/// post's comments (the `profile`, `profile_card` and `post` streams in
/// oci-backend/powersync/sync-config.yaml). Open one when the screen opens and
/// [close] it when it goes; the rows stay for the stream's time-to-live after
/// that, so going back and forth doesn't download them again.
///
/// Best-effort: a subscription that fails leaves the screen with what the
/// phone already has.
class SyncScope {
  SyncScope._(this._subscriptions);

  /// Subscribes to each `(stream, parameters)` of [streams] on [db], keeping
  /// the data [ttl] after [close].
  factory SyncScope.open(
    PowerSyncDatabase db,
    List<(String, Map<String, Object?>)> streams, {
    required Duration ttl,
  }) => SyncScope._(
    Future.wait([
      for (final (name, parameters) in streams)
        db.syncStream(name, parameters).subscribe(ttl: ttl),
    ]).catchError((Object _) => const <SyncStreamSubscription>[]),
  );

  /// A scope holding nothing (e.g. for the user's own profile, which always
  /// syncs).
  SyncScope.none() : _subscriptions = Future.value(const []);

  final Future<List<SyncStreamSubscription>> _subscriptions;
  bool _closed = false;

  /// Completes once the scope's data has arrived the first time (at once if
  /// it is already on the phone), or right away if subscribing failed.
  Future<void> get synced async {
    for (final subscription in await _subscriptions) {
      await subscription.waitForFirstSync();
    }
  }

  /// The screen is gone: the data may go once its time-to-live runs out.
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(
      _subscriptions.then((subscriptions) {
        for (final subscription in subscriptions) {
          subscription.unsubscribe();
        }
      }),
    );
  }
}

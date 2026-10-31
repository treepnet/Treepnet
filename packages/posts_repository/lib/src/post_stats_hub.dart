import 'dart:async';

import 'package:database_client/database_client.dart';

/// Serves [PostStats] to every post card on screen from ONE live query.
///
/// Each card used to open five live queries (likes, comments, liked, saved,
/// following) and PowerSync re-ran every one of them on any change to those
/// tables: one like made each card on screen re-query and rebuild. Now a card
/// subscribes here with its post id; the hub keeps a single
/// `DatabaseClient.postStatsOf` query over all subscribed ids (restarted,
/// shortly after, when cards come and go) and passes each card only its own
/// stats, and only when they changed.
class PostStatsHub {
  /// Creates a [PostStatsHub] that queries through the given client.
  PostStatsHub(this._databaseClient);

  final DatabaseClient _databaseClient;

  final _listeners = <String, Set<StreamController<PostStats>>>{};
  final _latest = <String, PostStats>{};
  StreamSubscription<Map<String, PostStats>>? _query;
  Timer? _restart;

  /// The live stats of the post [postId]. The current value, if any, comes
  /// first.
  Stream<PostStats> statsOf(String postId) {
    late final StreamController<PostStats> controller;
    controller = StreamController<PostStats>(
      onListen: () {
        final listeners = _listeners.putIfAbsent(postId, () => {});
        final isNew = listeners.isEmpty;
        listeners.add(controller);
        final latest = _latest[postId];
        if (latest != null) controller.add(latest);
        if (isNew) _scheduleRestart();
      },
      onCancel: () {
        final listeners = _listeners[postId];
        if (listeners == null) return;
        listeners.remove(controller);
        if (listeners.isEmpty) {
          _listeners.remove(postId);
          _latest.remove(postId);
          _scheduleRestart();
        }
      },
    );
    return controller.stream;
  }

  /// Cards built in the same frame (a page of the feed) share one restart.
  void _scheduleRestart() {
    _restart?.cancel();
    _restart = Timer(const Duration(milliseconds: 50), _restartQuery);
  }

  void _restartQuery() {
    // The last values stay in [_latest], so nobody sees a gap.
    unawaited(_query?.cancel());
    final ids = _listeners.keys.toList();
    _query = ids.isEmpty
        ? null
        : _databaseClient
              .postStatsOf(postIds: ids)
              .listen(_deliver, onError: _deliverError);
  }

  void _deliver(Map<String, PostStats> stats) {
    stats.forEach((postId, value) {
      final listeners = _listeners[postId];
      if (listeners == null || _latest[postId] == value) return;
      _latest[postId] = value;
      for (final controller in [...listeners]) {
        controller.add(value);
      }
    });
  }

  void _deliverError(Object error, StackTrace stackTrace) {
    for (final listeners in _listeners.values) {
      for (final controller in [...listeners]) {
        controller.addError(error, stackTrace);
      }
    }
  }
}

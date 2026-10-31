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
class PostStatsHub extends StatsHub<PostStats> {
  /// Creates a [PostStatsHub] that queries through the given client.
  PostStatsHub(DatabaseClient databaseClient)
    : super((ids) => databaseClient.postStatsOf(postIds: ids));
}

/// [PostStatsHub] for comments: every comment on screen reads its likes and
/// liked-by state from one `DatabaseClient.commentStatsOf` query (each used
/// to open three).
class CommentStatsHub extends StatsHub<CommentStats> {
  /// Creates a [CommentStatsHub] that queries through the given client.
  CommentStatsHub(DatabaseClient databaseClient)
    : super((ids) => databaseClient.commentStatsOf(commentIds: ids));
}

/// One live query over every subscribed id, each subscriber getting only its
/// own value, and only when it changed (see [PostStatsHub]).
class StatsHub<T> {
  /// Creates a [StatsHub] that runs [_queryOf] for the subscribed ids.
  StatsHub(this._queryOf);

  final Stream<Map<String, T>> Function(List<String> ids) _queryOf;

  final _listeners = <String, Set<StreamController<T>>>{};
  final _latest = <String, T>{};
  StreamSubscription<Map<String, T>>? _query;
  Timer? _restart;

  /// The live value for [postId]. The current value, if any, comes first.
  Stream<T> statsOf(String postId) {
    late final StreamController<T> controller;
    controller = StreamController<T>(
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
        : _queryOf(ids).listen(_deliver, onError: _deliverError);
  }

  void _deliver(Map<String, T> stats) {
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

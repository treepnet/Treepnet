import 'dart:async';
import 'dart:collection';

/// What the server said about a post the phone doesn't keep — one from the
/// feed past the people the user follows, Trends, saved posts — as of the
/// list that brought it.
class RemotePostStats {
  /// Creates a [RemotePostStats].
  const RemotePostStats({
    required this.authorId,
    required this.likes,
    required this.comments,
    required this.likedByMe,
    required this.authorTier,
    required this.authorTierExpiresAt,
    required this.authorPlaces,
  });

  /// From a `feed_post` row (sql/sync_scoping.sql).
  factory RemotePostStats.fromRow(Map<String, dynamic> row) => RemotePostStats(
    authorId: row['user_id'] as String,
    likes: (row['likes_count'] as num?)?.toInt() ?? 0,
    comments: (row['comments_count'] as num?)?.toInt() ?? 0,
    likedByMe: row['liked_by_me'] == true,
    authorTier: (row['referral_tier'] as num?)?.toInt() ?? 0,
    authorTierExpiresAt: row['referral_tier_expires_at'] as String?,
    authorPlaces: (row['author_places'] as num?)?.toInt() ?? 0,
  );

  /// The post's author.
  final String authorId;

  /// Likes, the user's own included if [likedByMe].
  final int likes;

  /// Comments.
  final int comments;

  /// Whether the server had the user's like.
  final bool likedByMe;

  /// The author's badge tier and when it ends.
  final int authorTier;

  /// When [authorTier] ends.
  final String? authorTierExpiresAt;

  /// How many of the author's posts have a location.
  final int authorPlaces;
}

/// The [RemotePostStats] of the posts the server lists have brought, the
/// latest [_capacity] of them, and a signal when they change.
class RemotePosts {
  static const _capacity = 1000;

  final _stats = LinkedHashMap<String, RemotePostStats>();
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Fires after [putAll].
  Stream<void> get changes => _changes.stream;

  /// What the server last said about [postId], if a list brought it.
  RemotePostStats? operator [](String postId) => _stats[postId];

  /// Keeps [rows] (`feed_post` rows), newest last.
  void putAll(Iterable<Map<String, dynamic>> rows) {
    var changed = false;
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      _stats
        ..remove(id)
        ..[id] = RemotePostStats.fromRow(row);
      changed = true;
    }
    while (_stats.length > _capacity) {
      _stats.remove(_stats.keys.first);
    }
    if (changed) _changes.add(null);
  }

  /// Forgets everything (signing out).
  void clear() => _stats.clear();
}

/// Likes the user just gave or took back that the server's count may not
/// include yet. A count from the server (`post_stats`, `comments`) changes a
/// moment after the like syncs; until then it is shown one up or down, so the
/// number moves the moment the heart does.
class PendingLikes {
  static const _patience = Duration(seconds: 30);

  final _pending = <String, ({int base, bool likedBefore, DateTime at})>{};

  /// The user is changing their like on [id] (a post or a comment), whose
  /// server count is [base] and which they had liked if [likedBefore].
  void record(String id, {required int base, required bool likedBefore}) {
    final pending = _pending[id];
    // Changed again before the server moved: what counts is whether the like
    // was in the server's number, as first recorded.
    final inBase = pending != null && pending.base == base
        ? pending.likedBefore
        : likedBefore;
    _pending[id] = (base: base, likedBefore: inBase, at: DateTime.now());
  }

  /// [count], the server's count for [id], as it reads with the user's like
  /// state [liked]. Once the server's count moves (or after a while) it is
  /// taken as is.
  int apply(String id, {required int count, required bool liked}) {
    final pending = _pending[id];
    if (pending == null) return count;
    if (count != pending.base ||
        DateTime.now().difference(pending.at) > _patience) {
      _pending.remove(id);
      return count;
    }
    final adjusted = count + (liked ? 1 : 0) - (pending.likedBefore ? 1 : 0);
    return adjusted < 0 ? 0 : adjusted;
  }

  /// Forgets everything (signing out).
  void clear() => _pending.clear();
}

/// [build]'s stream, started again each time [restart] fires: a live query
/// that also has to re-run when something outside the database changes.
Stream<T> restartOn<T>(Stream<void> restart, Stream<T> Function() build) {
  late final StreamController<T> controller;
  StreamSubscription<T>? current;
  StreamSubscription<void>? restarts;

  void start() {
    unawaited(current?.cancel());
    current = build().listen(
      controller.add,
      onError: controller.addError,
    );
  }

  controller = StreamController<T>(
    onListen: () {
      start();
      restarts = restart.listen((_) => start());
    },
    onPause: () => current?.pause(),
    onResume: () => current?.resume(),
    onCancel: () async {
      await restarts?.cancel();
      await current?.cancel();
    },
  );
  return controller.stream;
}

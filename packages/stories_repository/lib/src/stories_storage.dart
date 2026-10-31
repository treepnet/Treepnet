part of 'stories_repository.dart';

/// Storage keys for the [StoriesStorage].
abstract class StoriesStorageKeys {
  /// The stories the user has seen, kept whole — the old format. Read once,
  /// moved to [seenStoryIds], then removed.
  static const userSeenStoriesCollection = '__user_seen_stories_collection__';

  /// The stories the user has seen: viewer id → story id → when it expires.
  static const seenStoryIds = '__user_seen_story_ids__';
}

/// Viewer id → seen story id → when that story expires.
typedef SeenStoryIds = Map<String, Map<String, DateTime>>;

/// {@template stories_storage}
/// Manages storage and retrieval of seen stories for users.
///
/// Keeps only ids and expiry, and drops stories once they expire. The old
/// list kept every story whole (author and all), rewrote it twice per story
/// viewed, and never shrank — its clean-up was a lazy `.map` that never ran
/// — while the app read it all in on every start.
/// {@endtemplate}
class StoriesStorage {
  /// {@macro stories_storage}
  StoriesStorage({
    required Storage storage,
  }) : _storage = storage {
    _ready = _init();
  }

  final Storage _storage;
  late final Future<void> _ready;

  final _seen = BehaviorSubject<SeenStoryIds>.seeded(const {});

  Future<void> _init() async {
    try {
      final current = await _storage.read(key: StoriesStorageKeys.seenStoryIds);
      if (current != null) {
        _seen.add(_pruned(_decode(current)));
        return;
      }
      final legacy = await _storage.read(
        key: StoriesStorageKeys.userSeenStoriesCollection,
      );
      if (legacy == null) return;
      final seen = _pruned(await compute(_fromLegacy, legacy));
      _seen.add(seen);
      await _save(seen);
      await _storage.delete(key: StoriesStorageKeys.userSeenStoriesCollection);
    } catch (_) {
      // Unreadable: start from nothing seen rather than not at all.
    }
  }

  static SeenStoryIds _decode(String value) => {
    for (final MapEntry(key: userId, value: stories)
        in (jsonDecode(value) as Map<String, dynamic>).entries)
      userId: {
        for (final MapEntry(key: storyId, value: expires)
            in (stories as Map<String, dynamic>).entries)
          storyId: DateTime.parse(expires as String),
      },
  };

  /// The old list: `[{user_id, stories: [<whole story>]}]`.
  static SeenStoryIds _fromLegacy(String value) {
    final result = <String, Map<String, DateTime>>{};
    for (final entry in jsonDecode(value) as List<dynamic>) {
      final seen = entry as Map<String, dynamic>;
      final stories = <String, DateTime>{};
      for (final item in seen['stories'] as List<dynamic>? ?? const []) {
        final story = item as Map<String, dynamic>;
        final id = story['id'] as String?;
        final expires = DateTime.tryParse(
          story['expires_at'] as String? ?? '',
        );
        if (id != null && expires != null) stories[id] = expires;
      }
      if (stories.isNotEmpty) {
        result[seen['user_id'] as String? ?? ''] = stories;
      }
    }
    return result;
  }

  /// Without the stories that have expired, and the viewers left with none.
  static SeenStoryIds _pruned(SeenStoryIds seen) {
    final now = DateTime.now();
    final result = <String, Map<String, DateTime>>{};
    seen.forEach((userId, stories) {
      final live = {
        for (final story in stories.entries)
          if (story.value.isAfter(now)) story.key: story.value,
      };
      if (live.isNotEmpty) result[userId] = live;
    });
    return result;
  }

  Future<void> _save(SeenStoryIds seen) => _storage.write(
    key: StoriesStorageKeys.seenStoryIds,
    value: json.encode({
      for (final MapEntry(key: userId, value: stories) in seen.entries)
        userId: {
          for (final story in stories.entries)
            story.key: story.value.toIso8601String(),
        },
    }),
  );

  /// [stories], those in [seenIds] marked seen.
  List<Story> mergeStories(
    List<Story> stories, {
    required Set<String> seenIds,
  }) => [
    for (final story in stories)
      seenIds.contains(story.id) ? story.copyWith(seen: true) : story,
  ];

  /// Adds [story] to the stories [userId] has seen: one write, expired
  /// stories dropped on the way.
  Future<void> setUserStorySeen(Story story, String userId) async {
    await _ready;
    final seen = _pruned(_seen.value);
    final mine = {...?seen[userId]};
    if (mine.containsKey(story.id)) return;
    mine[story.id] = story.expiresAt;
    seen[userId] = mine;
    _seen.add(seen);
    await _save(seen);
  }
}

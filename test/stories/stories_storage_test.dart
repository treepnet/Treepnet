import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';
import 'package:storage/storage.dart';
import 'package:stories_repository/stories_repository.dart';

class _MemoryStorage implements Storage {
  final values = <String, String>{};
  var writes = 0;

  @override
  String? read({required String key}) => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    writes++;
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}

Story _story(String id, {required Duration expiresIn}) => Story(
  id: id,
  contentUrl: 'https://example.com/$id.jpg',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(expiresIn),
);

Map<String, dynamic> _saved(_MemoryStorage storage) =>
    jsonDecode(storage.values[StoriesStorageKeys.seenStoryIds]!)
        as Map<String, dynamic>;

void main() {
  test('the old list moves to ids only, expired ones dropped', () async {
    final storage = _MemoryStorage();
    storage.values[StoriesStorageKeys.userSeenStoriesCollection] = jsonEncode([
      {
        'user_id': 'me',
        'stories': [
          _story('old', expiresIn: const Duration(hours: -1)).toJson(),
          _story('live', expiresIn: const Duration(hours: 5)).toJson(),
        ],
      },
      {
        'user_id': 'gone',
        'stories': [
          _story('old2', expiresIn: const Duration(hours: -3)).toJson(),
        ],
      },
    ]);
    final seen = StoriesStorage(storage: storage);
    // Waits for the migration, then adds one.
    await seen.setUserStorySeen(
      _story('new', expiresIn: const Duration(hours: 1)),
      'me',
    );

    expect(
      storage.values.containsKey(StoriesStorageKeys.userSeenStoriesCollection),
      isFalse,
    );
    final saved = _saved(storage);
    expect(saved.keys, ['me']);
    expect((saved['me'] as Map).keys.toSet(), {'live', 'new'});
  });

  test('a story seen is written once, and once only', () async {
    final storage = _MemoryStorage();
    final seen = StoriesStorage(storage: storage);
    final story = _story('s1', expiresIn: const Duration(hours: 1));
    await seen.setUserStorySeen(story, 'me');
    await seen.setUserStorySeen(story, 'me');
    expect(storage.writes, 1);
  });

  test('mergeStories marks the seen ones', () {
    final seen = StoriesStorage(storage: _MemoryStorage());
    final merged = seen.mergeStories(
      [
        _story('a', expiresIn: const Duration(hours: 1)),
        _story('b', expiresIn: const Duration(hours: 1)),
      ],
      seenIds: {'b'},
    );
    expect([for (final s in merged) s.seen], [false, true]);
  });
}

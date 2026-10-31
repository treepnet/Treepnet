import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';

class _MockDatabaseClient extends Mock implements DatabaseClient {}

PostStats _stats({int likes = 0, bool isLiked = false}) => PostStats(
  likes: likes,
  comments: 0,
  isLiked: isLiked,
  isBookmarked: false,
  isAuthorFollowed: false,
  authorTier: 0,
  authorPlaces: 0,
);

/// Post cards share one live query (PostStatsHub) instead of five each.
void main() {
  late _MockDatabaseClient db;
  late List<List<String>> queries;
  late StreamController<Map<String, PostStats>> results;

  // Past the hub's 50 ms batching of cards that come and go together.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  setUp(() {
    db = _MockDatabaseClient();
    queries = [];
    when(
      () => db.postStatsOf(postIds: any(named: 'postIds')),
    ).thenAnswer((invocation) {
      queries.add(invocation.namedArguments[#postIds] as List<String>);
      results = StreamController<Map<String, PostStats>>();
      return results.stream;
    });
  });

  test('cards on screen share one query', () async {
    final posts = PostsRepository(databaseClient: db);
    final a = posts.statsOf(postId: 'a').listen((_) {});
    final b = posts.statsOf(postId: 'b').listen((_) {});
    await settle();
    expect(queries, [
      ['a', 'b'],
    ]);
    await a.cancel();
    await b.cancel();
  });

  test('each card gets its own stats, and only when they change', () async {
    final posts = PostsRepository(databaseClient: db);
    final seenA = <PostStats>[];
    final seenB = <PostStats>[];
    final a = posts.statsOf(postId: 'a').listen(seenA.add);
    final b = posts.statsOf(postId: 'b').listen(seenB.add);
    await settle();

    results.add({'a': _stats(likes: 1), 'b': _stats(likes: 5)});
    await settle();
    // Someone likes b: a's card hears nothing.
    results.add({'a': _stats(likes: 1), 'b': _stats(likes: 6, isLiked: true)});
    await settle();

    expect(seenA, [_stats(likes: 1)]);
    expect(seenB, [_stats(likes: 5), _stats(likes: 6, isLiked: true)]);
    await a.cancel();
    await b.cancel();
  });

  test('a card that leaves is dropped from the query', () async {
    final posts = PostsRepository(databaseClient: db);
    final a = posts.statsOf(postId: 'a').listen((_) {});
    final b = posts.statsOf(postId: 'b').listen((_) {});
    await settle();
    await a.cancel();
    await settle();
    expect(queries.last, ['b']);
    await b.cancel();
  });

  test('a second card for the same post gets the stats at once', () async {
    final posts = PostsRepository(databaseClient: db);
    final first = posts.statsOf(postId: 'a').listen((_) {});
    await settle();
    results.add({'a': _stats(likes: 3)});
    await settle();

    final seen = <PostStats>[];
    final second = posts.statsOf(postId: 'a').listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [_stats(likes: 3)]);
    // Same post, same query: no restart.
    await settle();
    expect(queries, hasLength(1));
    await first.cancel();
    await second.cancel();
  });
}

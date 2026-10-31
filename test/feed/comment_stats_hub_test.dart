import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';

class _MockDatabaseClient extends Mock implements DatabaseClient {}

CommentStats _stats({int likes = 0, bool byAuthor = false}) => CommentStats(
  likes: likes,
  isLiked: false,
  isLikedByPostAuthor: byAuthor,
);

/// Comments on screen share one live query (CommentStatsHub) instead of
/// three each.
void main() {
  late _MockDatabaseClient db;
  late List<List<String>> queries;
  late StreamController<Map<String, CommentStats>> results;

  // Past the hub's 50 ms batching of comments that come and go together.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 80));

  setUp(() {
    db = _MockDatabaseClient();
    queries = [];
    when(
      () => db.commentStatsOf(commentIds: any(named: 'commentIds')),
    ).thenAnswer((invocation) {
      queries.add(invocation.namedArguments[#commentIds] as List<String>);
      results = StreamController<Map<String, CommentStats>>();
      return results.stream;
    });
  });

  test('comments on screen share one query, each hears only its own', () async {
    final posts = PostsRepository(databaseClient: db);
    final seenA = <CommentStats>[];
    final seenB = <CommentStats>[];
    final a = posts.commentStatsOfComment(commentId: 'a').listen(seenA.add);
    final b = posts.commentStatsOfComment(commentId: 'b').listen(seenB.add);
    await settle();
    expect(queries, [
      ['a', 'b'],
    ]);

    results.add({'a': _stats(likes: 1), 'b': _stats()});
    await settle();
    // The post's author likes b: a hears nothing.
    results.add({'a': _stats(likes: 1), 'b': _stats(likes: 1, byAuthor: true)});
    await settle();

    expect(seenA, [_stats(likes: 1)]);
    expect(seenB, [_stats(), _stats(likes: 1, byAuthor: true)]);
    await a.cancel();
    await b.cancel();
  });
}

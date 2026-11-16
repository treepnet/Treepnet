import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/src/active_stories.dart';
import 'package:test/test.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockDatabaseClient extends Mock implements DatabaseClient {}

Story _story(String id, String authorId) => Story(
  id: id,
  contentUrl: 'https://example.com/$id.jpg',
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  author: User(id: authorId),
);

void main() {
  late _MockDatabaseClient db;
  late List<StreamController<List<Story>>> queries;

  setUp(() {
    db = _MockDatabaseClient();
    queries = [];
    when(() => db.activeStories()).thenAnswer((_) {
      final query = StreamController<List<Story>>();
      queries.add(query);
      return query.stream;
    });
  });

  test('every ring shares one query while they listen', () async {
    final active = ActiveStories(db);
    final a = active.of('a').listen((_) {});
    final b = active.of('b').listen((_) {});
    await pumpEventQueue();
    expect(queries, hasLength(1));
    await a.cancel();
    await b.cancel();
  });

  test('after every listener has gone, the next one gets a fresh query', () async {
    // Signing out closes every ring and the tray; signing back in opens them
    // again. They used to get nothing until the app was restarted.
    final active = ActiveStories(db);
    final first = active.of('a').listen((_) {});
    await pumpEventQueue();
    queries.single.add([_story('old', 'a')]);
    await pumpEventQueue();
    await first.cancel();

    final seen = <List<Story>>[];
    final again = active.of('a').listen(seen.add);
    await pumpEventQueue();
    expect(queries, hasLength(2));
    queries.last.add([_story('new', 'a')]);
    await pumpEventQueue();

    // Only the new query's stories: nothing replayed from before.
    expect(seen.map((s) => s.map((x) => x.id).toList()), [
      ['new'],
    ]);
    await again.cancel();
  });
}

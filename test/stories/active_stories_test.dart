import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockDatabaseClient extends Mock implements DatabaseClient {}

Story _story(
  String id,
  String authorId, {
  Duration left = const Duration(hours: 1),
}) => Story(
      id: id,
      contentUrl: 'https://example.com/$id',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(left),
      author: User(id: authorId),
    );

/// Every story ring reads one shared live query (ActiveStories) instead of
/// opening its own per avatar.
void main() {
  late _MockDatabaseClient db;
  late StreamController<List<Story>> query;
  late int opened;
  late int closed;
  late StoriesRepository stories;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = _MockDatabaseClient();
    opened = 0;
    closed = 0;
    query = StreamController<List<Story>>(
      onListen: () => opened++,
      onCancel: () => closed++,
    );
    when(() => db.activeStories()).thenAnswer((_) => query.stream);
    when(() => db.currentUserId).thenReturn('me');
    stories = StoriesRepository(
      databaseClient: db,
      storage: StoriesStorage(
        storage: PersistentStorage(
          sharedPreferences: await SharedPreferences.getInstance(),
        ),
      ),
    );
  });

  test('every ring shares one query and gets its own author', () async {
    final seenA = <List<Story>>[];
    final seenB = <List<Story>>[];
    final a = stories
        .mergedStories(authorId: 'a', userId: 'me')
        .listen(seenA.add);
    final b = stories
        .mergedStories(authorId: 'b', userId: 'me')
        .listen(seenB.add);
    await settle();
    expect(opened, 1);

    // The same rows parse to equal stories each time the query re-runs.
    final a1 = _story('a1', 'a');
    final b1 = _story('b1', 'b');
    query.add([a1, b1]);
    await settle();
    expect(seenA.last.map((s) => s.id), ['a1']);
    expect(seenB.last.map((s) => s.id), ['b1']);

    // b posts again: a's ring hears nothing.
    final aEmits = seenA.length;
    query.add([a1, b1, _story('b2', 'b')]);
    await settle();
    expect(seenA.length, aEmits);
    expect(seenB.last.map((s) => s.id), ['b1', 'b2']);

    await a.cancel();
    await b.cancel();
  });

  test('a story drops out when its 24 hours are up', () async {
    final seen = <List<Story>>[];
    final ring = stories
        .mergedStories(authorId: 'a', userId: 'me')
        .listen(seen.add);
    await settle();
    query.add([
      _story('ending', 'a', left: const Duration(milliseconds: 200)),
      _story('staying', 'a'),
    ]);
    await settle();
    expect(seen.last.map((s) => s.id), ['ending', 'staying']);
    // The query doesn't re-run on its own; the expiry timer re-filters.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(seen.last.map((s) => s.id), ['staying']);
    await ring.cancel();
  });

  test('the query closes when the last ring leaves', () async {
    final a = stories
        .mergedStories(authorId: 'a', userId: 'me')
        .listen((_) {});
    final b = stories
        .mergedStories(authorId: 'b', userId: 'me')
        .listen((_) {});
    await settle();
    await a.cancel();
    await settle();
    expect(closed, 0);
    await b.cancel();
    await settle();
    expect(closed, 1);
  });
}

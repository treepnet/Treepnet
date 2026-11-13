// The test stubs PowerSync's and PostgREST's types, which the package reaches
// through powersync_repository.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:powersync_repository/powersync_repository.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockDatabase extends Mock implements PowerSyncDatabase {}

class _MockPostgrest extends Mock implements PostgrestClient {}

/// An RPC's answer, as PostgREST's builder (a Future) gives it.
class _Answer<T> extends Fake implements PostgrestFilterBuilder<T> {
  _Answer(this._value);

  final FutureOr<T> Function() _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      Future<T>.sync(_value).then(onValue, onError: onError);
}

const _story = 's1';

void main() {
  late _MockPowerSyncRepository repository;
  late _MockDatabase db;
  late _MockPostgrest postgrest;
  late PowerSyncDatabaseClient client;
  late StreamController<ResultSet> story;
  var serverCalls = 0;
  var offline = false;

  ResultSet rows(List<String> columns, List<List<Object?>> values) =>
      ResultSet(columns, null, values);

  setUp(() {
    serverCalls = 0;
    offline = false;
    repository = _MockPowerSyncRepository();
    db = _MockDatabase();
    postgrest = _MockPostgrest();
    story = StreamController<ResultSet>();
    when(() => repository.db()).thenReturn(db);
    when(() => repository.postgrest()).thenReturn(postgrest);
    when(
      () => db.watch(
        'SELECT visibility FROM stories WHERE id = ?',
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) => story.stream);
    // The phone has 3 views of it.
    when(
      () => db.watch(
        any(that: startsWith('SELECT COUNT(*) AS c FROM story_views')),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer(
      (_) => Stream.value(
        rows(
          ['c'],
          [
            [3],
          ],
        ),
      ),
    );
    // The server knows of 7.
    when(
      () => postgrest.rpc<dynamic>(
        'story_view_count',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) {
      serverCalls++;
      return _Answer<dynamic>(() => offline ? throw Exception('offline') : 7);
    });
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  tearDown(() => story.close());

  test('a story still shown: counted on the phone, nothing asked', () async {
    final counts = client.storyViewsCountOf(storyId: _story);
    story.add(
      rows(
        ['visibility'],
        [
          ['public'],
        ],
      ),
    );
    expect(await counts.first, 3);
    expect(serverCalls, 0);
  });

  test('an archived story: its views are asked for, once', () async {
    final seen = <int>[];
    final sub = client.storyViewsCountOf(storyId: _story).listen(seen.add);
    story
      ..add(
        rows(
          ['visibility'],
          [
            ['owner'],
          ],
        ),
      )
      // Another change on the stories table: not asked again.
      ..add(
        rows(
          ['visibility'],
          [
            ['owner'],
          ],
        ),
      );
    await pumpEventQueue();
    expect(seen, [7]);
    expect(serverCalls, 1);
    await sub.cancel();
  });

  test('archived while watched: moves to the server', () async {
    final seen = <int>[];
    final sub = client.storyViewsCountOf(storyId: _story).listen(seen.add);
    story.add(
      rows(
        ['visibility'],
        [
          ['public'],
        ],
      ),
    );
    await pumpEventQueue();
    story.add(
      rows(
        ['visibility'],
        [
          ['owner'],
        ],
      ),
    );
    await pumpEventQueue();
    expect(seen, [3, 7]);
    await sub.cancel();
  });

  test(
    "a story made on this phone (no visibility yet) counts what's here",
    () async {
      final counts = client.storyViewsCountOf(storyId: _story);
      story.add(
        rows(
          ['visibility'],
          [
            [null],
          ],
        ),
      );
      expect(await counts.first, 3);
      expect(serverCalls, 0);
    },
  );

  test("archived and offline: what the phone has", () async {
    offline = true;
    final counts = client.storyViewsCountOf(storyId: _story);
    story.add(
      rows(
        ['visibility'],
        [
          ['owner'],
        ],
      ),
    );
    expect(await counts.first, 3);
  });
}

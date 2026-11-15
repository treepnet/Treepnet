// The test stubs PowerSync's database type, which the package reaches
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

  final T _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      Future<T>.value(_value).then(onValue, onError: onError);
}

const _someone = '0b6f3c1e-8a52-4d7e-9c11-2f4a6b8d0e13';

void main() {
  late _MockPowerSyncRepository repository;
  late _MockDatabase db;
  late _MockPostgrest postgrest;
  late PowerSyncDatabaseClient client;

  /// The ids each `profile_cards` call asked for.
  late List<List<String>> asked;

  setUp(() {
    repository = _MockPowerSyncRepository();
    db = _MockDatabase();
    postgrest = _MockPostgrest();
    asked = [];
    when(() => repository.db()).thenReturn(db);
    when(() => repository.postgrest()).thenReturn(postgrest);
    // No profile is on the phone, so every card comes from the server.
    when(
      () => db.watch(any(), parameters: any(named: 'parameters')),
    ).thenAnswer((_) => Stream.value(ResultSet(const ['id'], null, const [])));
    when(
      () => postgrest.rpc<List<dynamic>>(
        'profile_cards',
        params: any(named: 'params'),
      ),
    ).thenAnswer((invocation) {
      final params = invocation.namedArguments[#params] as Map;
      asked.add([...(params['p_ids'] as List).cast<String>()]);
      // The answer itself doesn't matter here: which ids were sent does.
      throw Exception('offline');
    });
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  group('travelTierOf', () {
    test('an empty id has no badge and asks nothing', () async {
      expect(await client.travelTierOf(userId: '').first, 0);
      verifyNever(() => repository.db());
      verifyNever(() => repository.postgrest());
    });
  });

  group('profile cards', () {
    test('an empty id is never sent with the others', () async {
      await client.profilesOf(ids: const ['', _someone]).first;
      expect(asked, [
        [_someone],
      ]);
    });

    test('only ids that are not UUIDs: no call at all', () async {
      final profiles = await client
          .profilesOf(ids: const ['', 'not-a-uuid'])
          .first;
      expect(profiles, isEmpty);
      expect(asked, isEmpty);
    });

    test('more than the server reads per call go in parts of 200', () async {
      // `profile_cards` reads the first 200 ids only: everyone past them came
      // back empty and left the list (a long inbox, blocked or saved list).
      when(
        () => postgrest.rpc<List<dynamic>>(
          'profile_cards',
          params: any(named: 'params'),
        ),
      ).thenAnswer((invocation) {
        final params = invocation.namedArguments[#params] as Map;
        final ids = (params['p_ids'] as List).cast<String>();
        asked.add(ids);
        return _Answer<List<dynamic>>([
          for (final id in ids.take(200)) {'id': id, 'username': 'user-$id'},
        ]);
      });
      final ids = [
        for (var i = 0; i < 450; i++)
          '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      ];

      final profiles = await client.profilesOf(ids: ids).first;

      expect(asked.map((part) => part.length), [200, 200, 50]);
      expect(profiles.keys.toSet(), ids.toSet());
    });

    test('a badge asked for at the same moment goes out alone', () async {
      // The profile page's empty id and a story author's real one, within
      // the same 50 ms: before, both went in one call that the server
      // refused for the empty id.
      await Future.wait([
        client.travelTierOf(userId: '').first,
        client.travelTierOf(userId: _someone).first,
      ]);
      expect(asked, [
        [_someone],
      ]);
    });
  });
}

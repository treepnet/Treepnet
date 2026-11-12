// The test stubs PowerSync's database type, which the package reaches
// through powersync_repository.
// ignore_for_file: depend_on_referenced_packages

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:powersync_repository/powersync_repository.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockDatabase extends Mock implements PowerSyncDatabase {}

class _MockPostgrest extends Mock implements PostgrestClient {}

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

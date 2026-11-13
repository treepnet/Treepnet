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

const _me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _them = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late _MockPowerSyncRepository repository;
  late _MockDatabase db;
  late PowerSyncDatabaseClient client;

  setUp(() {
    repository = _MockPowerSyncRepository();
    db = _MockDatabase();
    when(() => repository.db()).thenReturn(db);
    when(
      () => db.getAll(any(), any()),
    ).thenAnswer((_) async => ResultSet(const ['id'], null, const []));
    when(
      () => db.getOptional(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => db.execute(any(), any()),
    ).thenAnswer((_) async => ResultSet(const [], null, const []));
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  // A profile page whose user hasn't loaded yet had an empty id: the change
  // was written, the app said "Saved" / "Blocked", the server refused it.
  final changes = <String, Future<void> Function(String other)>{
    'saveProfile': (other) =>
        client.saveProfile(userId: _me, profileId: other),
    'unsaveProfile': (other) =>
        client.unsaveProfile(userId: _me, profileId: other),
    'blockUser': (other) => client.blockUser(userId: _me, blockedId: other),
    'unblockUser': (other) =>
        client.unblockUser(userId: _me, blockedId: other),
  };

  for (final MapEntry(key: name, value: change) in changes.entries) {
    group(name, () {
      test('refuses an empty id and writes nothing', () async {
        await expectLater(change(''), throwsArgumentError);
        verifyNever(() => repository.db());
      });

      test('refuses an id that is not a UUID', () async {
        await expectLater(change('Unknown'), throwsArgumentError);
        verifyNever(() => repository.db());
      });

      test('writes a real one', () async {
        await change(_them);
        verify(() => db.execute(any(), any())).called(greaterThan(0));
      });
    });
  }
}

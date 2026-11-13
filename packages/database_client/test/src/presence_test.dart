import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync_repository/powersync_repository.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockPostgrest extends Mock implements PostgrestClient {}

void main() {
  late _MockPowerSyncRepository repository;
  late _MockPostgrest postgrest;
  late PowerSyncDatabaseClient client;

  setUp(() {
    AuthSession.instance.update(
      AuthTokens(
        idToken: 't',
        accessToken: '',
        refreshToken: null,
        idTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        claims: const {'sub': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'},
      ),
    );
    repository = _MockPowerSyncRepository();
    postgrest = _MockPostgrest();
    when(() => repository.postgrest()).thenReturn(postgrest);
    // Offline: the call fails.
    when(() => postgrest.rpc<void>('touch_presence')).thenThrow(Exception('x'));
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  tearDown(AuthSession.instance.clear);

  test('the beat is one call to the server, nothing on the phone', () async {
    await client.touchPresence();
    verify(() => postgrest.rpc<void>('touch_presence')).called(1);
    // It used to be a write to `profiles` in the sync database, which re-ran
    // nearly every live query and queued offline.
    verifyNever(() => repository.db());
  });

  test("offline it's just skipped", () async {
    await expectLater(client.touchPresence(), completes);
  });

  test('signed out: nothing', () async {
    AuthSession.instance.clear();
    await client.touchPresence();
    verifyNever(() => postgrest.rpc<void>(any()));
  });
}

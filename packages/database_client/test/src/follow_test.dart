// The test stubs PowerSync's database types, which the package reaches
// through powersync_repository.
// ignore_for_file: depend_on_referenced_packages

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
import 'package:powersync/sqlite_async.dart' show SqliteWriteContext;
import 'package:powersync_repository/powersync_repository.dart';
import 'package:user_repository/user_repository.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockDatabase extends Mock implements PowerSyncDatabase {}

class _MockTx extends Mock implements SqliteWriteContext {}

class _MockPostgrest extends Mock implements PostgrestClient {}

const _me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _them = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

void main() {
  late _MockDatabase db;
  late _MockTx tx;
  late _MockPostgrest postgrest;
  late PowerSyncDatabaseClient client;
  late List<List<Object?>> inserted;

  /// [subscribed]: a follow row already there. [localPrivate]: their profile
  /// on the phone (null: not there).
  void given({bool subscribed = false, bool? localPrivate}) {
    when(() => db.getOptional(any(), any())).thenAnswer(
      (_) async => localPrivate == null
          ? null
          : ResultSet(const ['is_private'], null, [
              [if (localPrivate) 1 else 0],
            ]).first,
    );
    when(() => tx.getOptional(any(), any())).thenAnswer(
      (_) async => subscribed
          ? ResultSet(const ['1'], null, const [
              [1],
            ]).first
          : null,
    );
    // The server's card can't be had here (offline): unknown.
    when(
      () => postgrest.rpc<List<dynamic>>(
        'profile_cards',
        params: any(named: 'params'),
      ),
    ).thenThrow(Exception('offline'));
  }

  tearDown(AuthSession.instance.clear);

  setUp(() {
    AuthSession.instance.update(
      AuthTokens(
        idToken: 't',
        accessToken: '',
        refreshToken: null,
        idTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        claims: const {'sub': _me},
      ),
    );
    final repository = _MockPowerSyncRepository();
    db = _MockDatabase();
    tx = _MockTx();
    postgrest = _MockPostgrest();
    inserted = [];
    when(() => repository.db()).thenReturn(db);
    when(() => repository.postgrest()).thenReturn(postgrest);
    // follow()'s transaction body returns nothing: T is Null.
    when(() => db.writeTransaction<Null>(any())).thenAnswer(
      (invocation) => (invocation.positionalArguments.first as Future<Null>
          Function(SqliteWriteContext))(tx),
    );
    when(() => tx.execute(any(), any())).thenAnswer((invocation) async {
      inserted.add(invocation.positionalArguments[1] as List<Object?>);
      return ResultSet(const [], null, const []);
    });
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  test('already following or asked: nothing (it used to unfollow)', () async {
    given(subscribed: true, localPrivate: false);
    await client.follow(followToId: _them);
    verifyNever(() => tx.execute(any(), any()));
  });

  test('a public account on the phone: followed outright', () async {
    given(localPrivate: false);
    await client.follow(followToId: _them);
    expect(inserted.single.last, 'accepted');
  });

  test('a private account on the phone: a request', () async {
    given(localPrivate: true);
    await client.follow(followToId: _them);
    expect(inserted.single.last, 'pending');
  });

  test('not on the phone and unknown: a request, not "Following"', () async {
    given();
    await client.follow(followToId: _them);
    expect(inserted.single.last, 'pending');
  });
}

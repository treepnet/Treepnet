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

/// A post not on the phone comes from the server: "not there" (or not to be
/// seen) and "couldn't be read" are different answers now. Both were null,
/// so a post that failed to load read "No post found".
void main() {
  late _MockPostgrest postgrest;
  late PowerSyncDatabaseClient client;
  late FutureOr<List<dynamic>> Function() server;

  setUp(() {
    final repository = _MockPowerSyncRepository();
    final db = _MockDatabase();
    postgrest = _MockPostgrest();
    when(() => repository.db()).thenReturn(db);
    when(() => repository.postgrest()).thenReturn(postgrest);
    // Not on the phone.
    when(() => db.getOptional(any(), any())).thenAnswer((_) async => null);
    when(
      () => postgrest.rpc<List<dynamic>>(
        'post_by_id',
        params: any(named: 'params'),
      ),
    ).thenAnswer((_) => _Answer<List<dynamic>>(() => server()));
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  test('the server has no such post (or it may not be seen): null', () async {
    server = () => <dynamic>[];
    expect(await client.getPostBy(id: 'p1'), isNull);
  });

  test('the server could not be asked: PostLoadFailed', () async {
    server = () => throw Exception('offline');
    await expectLater(
      client.getPostBy(id: 'p1'),
      throwsA(isA<PostLoadFailed>()),
    );
  });
}

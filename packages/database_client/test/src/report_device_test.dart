import 'dart:async';

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

  Future<void> report() => client.reportDevice(
    deviceId: '11111111-1111-4111-8111-111111111111',
    platform: 'ios',
    appVersion: '1.0.9',
    build: 9,
    osVersion: '18.1',
    model: 'iPhone 15 Pro',
  );

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
    when(
      () => postgrest.rpc<void>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => _Answer<void>(() {}));
    client = PowerSyncDatabaseClient(powerSyncRepository: repository);
  });

  tearDown(AuthSession.instance.clear);

  test('the phone goes to report_device, by name', () async {
    await report();
    final params =
        verify(
              () => postgrest.rpc<void>(
                'report_device',
                params: captureAny(named: 'params'),
              ),
            ).captured.single
            as Map;
    expect(params, {
      'p_device_id': '11111111-1111-4111-8111-111111111111',
      'p_platform': 'ios',
      'p_app_version': '1.0.9',
      'p_build': 9,
      'p_os_version': '18.1',
      'p_model': 'iPhone 15 Pro',
    });
    verifyNever(() => repository.db());
  });

  test('signed out: sent all the same (an install with no account)', () async {
    AuthSession.instance.clear();
    await report();
    verify(
      () => postgrest.rpc<void>('report_device', params: any(named: 'params')),
    ).called(1);
  });
}

/// An RPC's answer, as PostgREST's builder (a Future) gives it.
class _Answer<T> extends Fake implements PostgrestFilterBuilder<T> {
  _Answer(this._value);

  final FutureOr<T> Function() _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      Future<T>.sync(_value).then(onValue, onError: onError);
}

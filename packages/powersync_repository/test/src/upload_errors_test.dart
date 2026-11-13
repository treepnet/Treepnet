// The test stubs PowerSync's database type, which the package reaches
// through package:powersync.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync/powersync.dart'
    show CrudEntry, CrudTransaction, PowerSyncDatabase, UpdateType;
import 'package:powersync_repository/powersync_repository.dart';

class _MockDatabase extends Mock implements PowerSyncDatabase {}

PostgrestException _error(String code) =>
    PostgrestException(message: 'x', code: code);

void main() {
  group('isPermanentUploadError', () {
    test('final: data, rules, missing table or column, a trigger', () {
      for (final code in [
        '22P02', // bad input
        '23505', // unique
        '23514', // check (a text limit)
        '42501', // permission / row-level security
        '42P01', // no such table
        '42703', // no such column
        '42883', // no such function
        'P0001', // a trigger refusing
        'PGRST102', // a body PostgREST can't read
        'PGRST204', // a column its schema doesn't have
        'PGRST205', // a table its schema doesn't have
        '400', '404', '405', '406', '409', '413', '422', // the proxy's
      ]) {
        expect(isPermanentUploadError(_error(code)), isTrue, reason: code);
      }
    });

    test('retried: network, server, token, slow down, transient', () {
      for (final code in [
        '401', '403', '408', '429', '500', '502', '503', '504',
        'PGRST000', 'PGRST001', 'PGRST002', // database unreachable
        'PGRST301', 'PGRST302', // the token
        '57014', // statement timeout (counted, see UploadAttempts)
        '40001', '40P01', // serialization, deadlock
        '53300', // too many connections
      ]) {
        expect(isPermanentUploadError(_error(code)), isFalse, reason: code);
      }
      expect(
        isPermanentUploadError(const PostgrestException(message: 'x')),
        isFalse,
      );
    });
  });

  group('UploadAttempts', () {
    test('counts failures of the same transaction in a row', () {
      final attempts = UploadAttempts();
      expect(attempts.failed(1), 1);
      expect(attempts.failed(1), 2);
      expect(attempts.failed(2), 1, reason: 'another transaction');
      attempts.done();
      expect(attempts.failed(2), 1, reason: 'after it went through');
    });

    test('a statement timing out every time is given up on', () {
      final attempts = UploadAttempts(stuckAfter: 3);
      expect(attempts.givesUp('57014', 2), isFalse);
      expect(attempts.givesUp('57014', 3), isTrue);
      expect(attempts.givesUp('503', 99), isFalse, reason: 'server down');
    });
  });

  group('the upload queue', () {
    late _MockDatabase db;
    late bool completed;
    late http.Response Function(http.Request request) answer;
    late List<RejectedUpload> rejected;
    late List<StuckUpload> stuck;
    late StreamSubscription<RejectedUpload> rejectedSub;
    late StreamSubscription<StuckUpload> stuckSub;
    final repository = PowerSyncRepository(env: (_) => '');
    var transactionId = 100;

    setUp(() {
      AuthSession.instance.update(
        AuthTokens(
          idToken: 'token',
          accessToken: '',
          refreshToken: null,
          idTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
          claims: const {},
        ),
      );
      db = _MockDatabase();
      completed = false;
      final id = transactionId++;
      when(() => db.getNextCrudTransaction()).thenAnswer(
        (_) async => CrudTransaction(
          crud: [
            CrudEntry(1, UpdateType.put, 'likes', 'like-1', id, const {
              'user_id': 'u',
            }),
          ],
          complete: ({String? writeCheckpoint}) async => completed = true,
          transactionId: id,
        ),
      );
      rejected = [];
      stuck = [];
      rejectedSub = repository.rejectedUploads.listen(rejected.add);
      stuckSub = repository.stuckUploads.listen(stuck.add);
    });

    tearDown(() async {
      AuthSession.instance.clear();
      await rejectedSub.cancel();
      await stuckSub.cancel();
    });

    SyncConnector connector() => SyncConnector(
      db,
      env: (_) => '',
      uploadClient: MockClient((request) async => answer(request)),
    );

    http.Response postgrest(http.Request request, int status, String code) =>
        http.Response(
          jsonEncode({'code': code, 'message': 'Could not find it'}),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );

    test('a column the server no longer has: dropped, not retried forever',
        () async {
      answer = (r) => postgrest(r, 400, 'PGRST204');
      await connector().uploadData(db);
      expect(completed, isTrue);
      expect(rejected.single.code, 'PGRST204');
    });

    test('too big for the proxy (a bare 413): dropped', () async {
      answer = (r) =>
          http.Response('Request Entity Too Large', 413, request: r);
      await connector().uploadData(db);
      expect(completed, isTrue);
      expect(rejected.single.code, '413');
    });

    test('the server down: kept and retried', () async {
      answer = (r) => http.Response('Bad Gateway', 502, request: r);
      await expectLater(connector().uploadData(db), throwsA(anything));
      expect(completed, isFalse);
      expect(rejected, isEmpty);
    });

    test('off the network for long: reported once as stuck, never dropped',
        () async {
      final client = SyncConnector(
        db,
        env: (_) => '',
        uploadClient: MockClient((_) async => throw http.ClientException('x')),
      );
      for (var i = 0; i < 35; i++) {
        await expectLater(client.uploadData(db), throwsA(anything));
      }
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(stuck, hasLength(1));
      expect(stuck.single.table, 'likes');
      expect(rejected, isEmpty);
    });

    test('a statement that always times out: dropped after the tries',
        () async {
      answer = (r) => postgrest(r, 500, '57014');
      final client = connector();
      for (var i = 0; i < 29; i++) {
        await expectLater(client.uploadData(db), throwsA(anything));
      }
      expect(completed, isFalse);
      await client.uploadData(db);
      expect(completed, isTrue);
      expect(rejected.single.code, '57014');
    });
  });
}

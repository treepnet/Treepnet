// fake_async comes with flutter_test.
// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:powersync_repository/powersync_repository.dart';

/// The client the upload queue and the RPCs share: what it adds to a request
/// and how long it waits.
void main() {
  tearDown(AuthSession.instance.clear);

  http.Request upload({String? token}) =>
      http.Request('POST', Uri.parse('https://api.example/likes'))
        ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'});

  test('a call that never answers fails after the time limit', () {
    fakeAsync((async) {
      // A stalled network: the request goes out and nothing comes back.
      final client = FreshTokenClient(
        inner: MockClient((_) => Completer<http.Response>().future),
      );
      Object? failure;
      unawaited(client.send(upload()).then((_) {}, onError: (Object e) {
        failure = e;
      }));
      async.elapse(FreshTokenClient.timeout - const Duration(seconds: 1));
      expect(failure, isNull);
      async.elapse(const Duration(seconds: 2));
      // The upload queue rethrows it and tries again later, instead of
      // waiting for good with every change behind it.
      expect(failure, isA<TimeoutException>());
    });
  });

  test('signed in: the current token goes on the request', () async {
    AuthSession.instance.update(
      AuthTokens(
        idToken: 'current',
        accessToken: '',
        refreshToken: null,
        idTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
        claims: const {},
      ),
    );
    String? sent;
    final client = FreshTokenClient(
      inner: MockClient((request) async {
        sent = request.headers['Authorization'];
        return http.Response('', 201);
      }),
    );
    await client.send(upload(token: 'older'));
    expect(sent, 'Bearer current');
  });

  test('signed out meanwhile: the token the upload began with stays', () async {
    String? sent;
    final client = FreshTokenClient(
      inner: MockClient((request) async {
        sent = request.headers['Authorization'];
        return http.Response('', 201);
      }),
    );
    await client.send(upload(token: 'began-with'));
    expect(sent, 'Bearer began-with');
  });
}

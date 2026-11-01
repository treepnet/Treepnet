import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:powersync_repository/powersync_repository.dart';

AuthTokens _tokens(String idToken, {required Duration expiresIn}) =>
    AuthTokens(
      idToken: idToken,
      accessToken: '',
      refreshToken: null,
      idTokenExpiry: DateTime.now().add(expiresIn),
      claims: const {'sub': 'user-1'},
    );

void main() {
  late List<http.BaseRequest> sent;
  late int refreshes;

  FreshTokenClient client() => FreshTokenClient(
    inner: MockClient((request) async {
      sent.add(request);
      return http.Response(
        '[]',
        200,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  setUp(() {
    sent = [];
    refreshes = 0;
    AuthSession.instance.registerRefresher(() async {
      refreshes++;
      AuthSession.instance.update(
        _tokens('fresh', expiresIn: const Duration(hours: 1)),
      );
    });
  });

  tearDown(AuthSession.instance.clear);

  test('a valid token is sent as it is', () async {
    AuthSession.instance.update(
      _tokens('valid', expiresIn: const Duration(minutes: 30)),
    );
    await client().get(Uri.parse('https://api.example/x'));

    expect(sent.single.headers['Authorization'], 'Bearer valid');
    expect(refreshes, 0);
  });

  test('an expired token is refreshed before the request', () async {
    AuthSession.instance.update(
      _tokens('stale', expiresIn: const Duration(minutes: -5)),
    );
    await client().get(Uri.parse('https://api.example/x'));

    expect(refreshes, 1);
    expect(sent.single.headers['Authorization'], 'Bearer fresh');
  });

  test('signed out: the request goes without a token', () async {
    AuthSession.instance.clear();
    await client().get(Uri.parse('https://api.example/x'));

    expect(sent.single.headers.containsKey('Authorization'), isFalse);
  });

  test('a refresh that fails stops the request', () async {
    AuthSession.instance
      ..registerRefresher(() async => throw Exception('offline'))
      ..update(_tokens('stale', expiresIn: const Duration(minutes: -5)));

    await expectLater(
      client().get(Uri.parse('https://api.example/x')),
      throwsException,
    );
    expect(sent, isEmpty);
  });

  test('PostgREST calls carry the fresh token', () async {
    AuthSession.instance.update(
      _tokens('stale', expiresIn: const Duration(minutes: -5)),
    );
    await PostgrestClient(
      'https://api.example',
      httpClient: client(),
    ).from('profiles').select('id');

    expect(sent.single.url.path, '/profiles');
    expect(sent.single.headers['Authorization'], 'Bearer fresh');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:token_storage/token_storage.dart';

/// Signing out must not throw.
///
/// The auth client's `user` stream used to be a hand-built `StreamController`
/// whose `onCancel` called an async `sub.cancel()`. Any session change landing
/// in that window was added to a controller that had already gone away, and
/// `Bad state: Cannot add event after closing` was thrown — repeatedly, on
/// every sign-out. The stream is a generator now, which cancels its source as
/// part of being cancelled.
///
/// [AuthSession] is the shared surface both sides talk through, so these
/// exercise the contract the client depends on.
void main() {
  final tokens = AuthTokens(
    idToken: 'id',
    accessToken: 'access',
    refreshToken: 'refresh',
    idTokenExpiry: DateTime.utc(2030),
    claims: const {'oid': '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4'},
  );

  tearDown(() => AuthSession.instance.clear());

  test('changes survives a listener that comes and goes', () async {
    final seen = <AuthTokens?>[];
    final first = AuthSession.instance.changes.listen(seen.add);

    AuthSession.instance.update(tokens);
    await Future<void>.delayed(Duration.zero);
    await first.cancel();

    // The signal that used to blow up: a change with the old listener gone.
    expect(AuthSession.instance.clear, returnsNormally);
    await Future<void>.delayed(Duration.zero);

    // A fresh listener still works — the session is not a one-shot.
    final later = <AuthTokens?>[];
    final second = AuthSession.instance.changes.listen(later.add);
    AuthSession.instance.update(tokens);
    await Future<void>.delayed(Duration.zero);

    expect(seen.length, 1);
    expect(later.single?.idToken, 'id');
    await second.cancel();
  });

  test('clear empties the session and announces it', () async {
    AuthSession.instance.update(tokens);
    expect(AuthSession.instance.isAuthenticated, isTrue);

    final seen = <AuthTokens?>[];
    final subscription = AuthSession.instance.changes.listen(seen.add);

    AuthSession.instance.clear();
    await Future<void>.delayed(Duration.zero);

    expect(AuthSession.instance.current, isNull);
    expect(AuthSession.instance.isAuthenticated, isFalse);
    // Null is how sign-out travels: the auth client maps it to the
    // anonymous user, which is what sends the router back to /auth.
    expect(seen.single, isNull);
    await subscription.cancel();
  });

  test('userId prefers an oid claim over sub', () {
    // The whole RLS layer compares this against `profiles.id`.
    expect(tokens.userId, '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4');
  });

  group('a session opened before its token came (offline start)', () {
    // What the auth client's restoreSession publishes when the token doesn't
    // come within two seconds: the user, and a token that counts as expired.
    final pending = AuthTokens(
      idToken: '',
      accessToken: '',
      refreshToken: null,
      idTokenExpiry: DateTime.fromMillisecondsSinceEpoch(0),
      claims: const {'sub': '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4'},
    );

    tearDown(() => AuthSession.instance.registerRefresher(() async {}));

    test('is signed in as the user, with no usable token', () {
      AuthSession.instance.update(pending);
      expect(AuthSession.instance.isAuthenticated, isTrue);
      expect(pending.userId, '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4');
      expect(pending.isIdTokenValid, isFalse);
    });

    test('idToken fetches the real one first', () async {
      AuthSession.instance.update(pending);
      AuthSession.instance.registerRefresher(
        () async => AuthSession.instance.update(tokens),
      );
      expect(await AuthSession.instance.idToken(), 'id');
    });

    test('idToken throws while offline, so the caller retries', () async {
      AuthSession.instance.update(pending);
      AuthSession.instance.registerRefresher(
        () async => throw Exception('network-request-failed'),
      );
      await expectLater(AuthSession.instance.idToken(), throwsException);
    });

    test('idToken never hands out the empty token', () async {
      AuthSession.instance.update(pending);
      AuthSession.instance.registerRefresher(() async {});
      expect(await AuthSession.instance.idToken(), isNull);
    });
  });
}

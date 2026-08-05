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
/// [EntraSession] is the shared surface both sides talk through, so these
/// exercise the contract the client depends on.
void main() {
  final tokens = EntraTokens(
    idToken: 'id',
    accessToken: 'access',
    refreshToken: 'refresh',
    idTokenExpiry: DateTime.utc(2030),
    claims: const {'oid': '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4'},
  );

  tearDown(() => EntraSession.instance.clear());

  test('changes survives a listener that comes and goes', () async {
    final seen = <EntraTokens?>[];
    final first = EntraSession.instance.changes.listen(seen.add);

    EntraSession.instance.update(tokens);
    await Future<void>.delayed(Duration.zero);
    await first.cancel();

    // The signal that used to blow up: a change with the old listener gone.
    expect(EntraSession.instance.clear, returnsNormally);
    await Future<void>.delayed(Duration.zero);

    // A fresh listener still works — the session is not a one-shot.
    final later = <EntraTokens?>[];
    final second = EntraSession.instance.changes.listen(later.add);
    EntraSession.instance.update(tokens);
    await Future<void>.delayed(Duration.zero);

    expect(seen.length, 1);
    expect(later.single?.idToken, 'id');
    await second.cancel();
  });

  test('clear empties the session and announces it', () async {
    EntraSession.instance.update(tokens);
    expect(EntraSession.instance.isAuthenticated, isTrue);

    final seen = <EntraTokens?>[];
    final subscription = EntraSession.instance.changes.listen(seen.add);

    EntraSession.instance.clear();
    await Future<void>.delayed(Duration.zero);

    expect(EntraSession.instance.current, isNull);
    expect(EntraSession.instance.isAuthenticated, isFalse);
    // Null is how sign-out travels: the auth client maps it to the
    // anonymous user, which is what sends the router back to /auth.
    expect(seen.single, isNull);
    await subscription.cancel();
  });

  test('userId prefers oid — Entra sub is not a uuid', () {
    // The whole RLS layer compares this against `profiles.id`.
    expect(tokens.userId, '15f0f1a5-76d2-4b98-a895-f1d9b59aa3b4');
  });
}

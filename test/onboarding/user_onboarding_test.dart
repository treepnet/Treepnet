import 'package:flutter_test/flutter_test.dart';
import 'package:user_repository/user_repository.dart';

/// Guards the two getters the onboarding gate and the avatar menu read.
///
/// The gate lives in the router's `redirect`, which runs on every navigation,
/// so getting these wrong is not a cosmetic bug: signing in emits an
/// identity-only user *before* the profile row arrives, and treating that one
/// as "never onboarded" would bounce every returning user into the intro.
void main() {
  group('User.hasProfile', () {
    test('is false for the identity-only user emitted before the row syncs',
        () {
      // What `User.fromAuthenticationUser` produces: no username, because
      // Entra's `preferred_username` is an email, not a handle.
      const user = User(id: 'abc', email: 'a@b.c');

      expect(user.hasProfile, isFalse);
    });

    test('is true once the profile row has loaded', () {
      const user = User(id: 'abc', username: 'hikmatcoder');

      expect(user.hasProfile, isTrue);
    });
  });

  group('User.needsOnboarding', () {
    test('is false while the profile is still syncing', () {
      const user = User(id: 'abc', email: 'a@b.c');

      // Null `onboardedAt` here means "unknown", not "never onboarded".
      expect(user.onboardedAt, isNull);
      expect(user.needsOnboarding, isFalse);
    });

    test('is true for a loaded profile that never finished the intro', () {
      const user = User(id: 'abc', username: 'hikmatcoder');

      expect(user.needsOnboarding, isTrue);
    });

    test('is false once the intro has been finished', () {
      const user = User(
        id: 'abc',
        username: 'hikmatcoder',
        onboardedAt: '2026-07-17T09:00:00.000Z',
      );

      expect(user.needsOnboarding, isFalse);
    });

    test('is false for the anonymous user', () {
      expect(User.anonymous.needsOnboarding, isFalse);
    });
  });

  group('User.fromJson', () {
    test('reads onboarded_at', () {
      final user = User.fromJson(const {
        'id': 'abc',
        'username': 'hikmatcoder',
        'onboarded_at': '2026-07-17T09:00:00.000Z',
      });

      expect(user.onboardedAt, '2026-07-17T09:00:00.000Z');
      expect(user.needsOnboarding, isFalse);
    });

    test('leaves onboarded_at null when the column is absent', () {
      final user = User.fromJson(const {'id': 'abc', 'username': 'x'});

      expect(user.onboardedAt, isNull);
      expect(user.needsOnboarding, isTrue);
    });
  });

  group('User.hasAvatar', () {
    test('is false when unset', () {
      expect(const User(id: 'abc').hasAvatar, isFalse);
    });

    test('is false for an empty or blank url', () {
      // Removal writes NULL, but blanks have reached this field before and the
      // avatar widget already falls back on them.
      expect(const User(id: 'abc', avatarUrl: '').hasAvatar, isFalse);
      expect(const User(id: 'abc', avatarUrl: '   ').hasAvatar, isFalse);
    });

    test('is true for a real url', () {
      const user = User(id: 'abc', avatarUrl: 'https://x/y.jpg');

      expect(user.hasAvatar, isTrue);
    });
  });
}

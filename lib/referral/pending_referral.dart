import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_repository/user_repository.dart';

/// Holds the invite handle captured from a link or the Play install referrer
/// until the user finishes REGISTERING.
///
/// A referral must only count for a brand-new account: the handle is persisted
/// here on capture and redeemed exactly once, from the sign-up flow. An already
/// registered user who taps an invite link (or logs back in) never redeems it,
/// so re-tapping a link can't inflate someone's invite count.
abstract class PendingReferral {
  static const _key = 'pending_referral_handle';

  /// The new account a redeem was attempted for but couldn't reach the
  /// server (no connection at sign-up): retried for that account only.
  static const _forKey = 'pending_referral_for';

  /// Stores the handle (no-op for an empty value). Survives an app restart, so
  /// an invite tapped before install still counts once the user signs up later.
  static Future<void> save(String handle) async {
    final trimmed = handle.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }

  /// The pending handle, or null when none was captured.
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    return (value != null && value.isNotEmpty) ? value : null;
  }

  /// Clears the stored handle once redeemed (or when no longer valid).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_forKey);
  }

  /// Redeems the pending handle for the just-created account [userId]. It is
  /// cleared only on the server's definitive answer; if the server couldn't
  /// be reached it stays, tied to [userId], for [retryFor] — it used to be
  /// dropped after three failed tries, and the invite was lost.
  static Future<void> redeemFor(
    UserRepository users, {
    required String userId,
    int attempts = 3,
  }) async {
    final handle = await read();
    if (handle == null) return;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final status = await users.redeemReferral(handle: handle);
        // "Not signed in yet" (the new session's token isn't through): retry.
        // Anything else is the server's verdict.
        if (status != 'unauthenticated') {
          await clear();
          return;
        }
      } catch (_) {
        // No connection, or the token isn't ready yet.
      }
      if (attempt < attempts - 1) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_forKey, userId);
  }

  /// Finishes a redeem that couldn't reach the server at sign-up, once
  /// [userId] — that same new account — is signed in again. (The server
  /// still accepts it only within an hour of sign-up.)
  static Future<void> retryFor(UserRepository users, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_forKey) != userId) return;
    await redeemFor(users, userId: userId, attempts: 1);
  }
}

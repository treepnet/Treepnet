import 'package:shared_preferences/shared_preferences.dart';

/// Holds the invite handle captured from a link or the Play install referrer
/// until the user finishes REGISTERING.
///
/// A referral must only count for a brand-new account: the handle is persisted
/// here on capture and redeemed exactly once, from the sign-up flow. An already
/// registered user who taps an invite link (or logs back in) never redeems it,
/// so re-tapping a link can't inflate someone's invite count.
abstract class PendingReferral {
  static const _key = 'pending_referral_handle';

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
  }
}

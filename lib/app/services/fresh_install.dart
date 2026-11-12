import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Recognises the first launch of a fresh install, so a session left by an
/// earlier install is not opened.
///
/// On iOS deleting the app doesn't sign out: Firebase keeps the session, and
/// the chat its identity, in the Keychain, which survives the uninstall. The
/// next person to install TreepNet on that phone (a family member, the
/// phone's next owner) opened straight into the old account, DMs included.
/// The app's own files and preferences do go with the uninstall, so:
///
/// * no marker in the preferences and no local database before this launch
///   opened it: a fresh install (or a reinstall), so the left-over session is
///   signed out ([clearOldSession]);
/// * no marker but a database: this install, updated from a version without
///   the marker. Nothing is signed out; the marker is just set.
class FreshInstall {
  const FreshInstall._();

  static const _key = 'treepnet_install_marker_v1';

  /// Whether the local database existed before this launch: read it before
  /// the database is opened (opening creates the file).
  static bool databaseExisted(String databasePath) =>
      File(databasePath).existsSync();

  /// Signs out a left-over session on a fresh install, then sets the marker.
  /// Never throws: a failure here must not stop the app from starting.
  static Future<void> check({
    required SharedPreferences preferences,
    required bool hadDatabase,
    required Future<void> Function() clearOldSession,
  }) async {
    try {
      if (preferences.getBool(_key) ?? false) return;
      if (!hadDatabase) await clearOldSession();
      await preferences.setBool(_key, true);
    } catch (_) {
      // Tried again on the next launch.
    }
  }
}

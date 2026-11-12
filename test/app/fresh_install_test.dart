import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/services/fresh_install.dart';

void main() {
  late int cleared;

  Future<SharedPreferences> prefs([Map<String, Object> values = const {}]) {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<void> run(SharedPreferences p, {required bool hadDatabase}) =>
      FreshInstall.check(
        preferences: p,
        hadDatabase: hadDatabase,
        clearOldSession: () async => cleared++,
      );

  setUp(() => cleared = 0);

  test(
    'a fresh install (or a reinstall) signs out a left-over session',
    () async {
      final p = await prefs();
      await run(p, hadDatabase: false);
      expect(cleared, 1);
      // And only on that first launch.
      await run(p, hadDatabase: true);
      expect(cleared, 1);
    },
  );

  test(
    'an update from a version without the marker keeps the session',
    () async {
      final p = await prefs();
      await run(p, hadDatabase: true);
      expect(cleared, 0);
      // Marked now: a later launch doesn't ask again.
      await run(p, hadDatabase: false);
      expect(cleared, 0);
    },
  );

  test('a failure is tried again next launch and never thrown', () async {
    final p = await prefs();
    await FreshInstall.check(
      preferences: p,
      hadDatabase: false,
      clearOldSession: () async => throw StateError('keychain locked'),
    );
    await run(p, hadDatabase: false);
    expect(cleared, 1);
  });
}

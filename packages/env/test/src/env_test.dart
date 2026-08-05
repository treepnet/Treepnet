import 'package:env/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards that every env var the app still needs was actually baked in.
///
/// The values are never logged: these are secrets, and test output travels.
void main() {
  group('Env', () {
    group('Dev', () {
      test('powersync url is set', () {
        expect(EnvDev.powersyncUrl, isNotEmpty);
      });
      test('ios client id is set', () {
        expect(EnvDev.iOSClientId, isNotEmpty);
      });
      test('web client id is set', () {
        expect(EnvDev.webClientId, isNotEmpty);
      });
    });
    group('Prod', () {
      test('powersync url is set', () {
        expect(EnvProd.powersyncUrl, isNotEmpty);
      });
      test('ios client id is set', () {
        expect(EnvProd.iOSClientId, isNotEmpty);
      });
      test('web client id is set', () {
        expect(EnvProd.webClientId, isNotEmpty);
      });
    });
  });
}

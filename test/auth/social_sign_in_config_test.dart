import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which "Continue with ..." buttons a build shows, and which work.
void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  const google = SocialProvider.google;
  const apple = SocialProvider.apple;

  test('nothing set up: no buttons (the release builds until it is)', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      debugDefaultTargetPlatformOverride = platform;
      const config = SocialSignInConfig();
      expect(config.offers(google), isFalse);
      expect(config.offers(apple), isFalse);
    }
  });

  test('Apple is the iPhone only', () {
    const config = SocialSignInConfig(apple: true, showUnconfigured: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(config.isReady(apple), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(config.isReady(apple), isFalse);
    expect(config.offers(apple), isFalse);
  });

  test("Google needs each platform's own client id", () {
    const androidOnly = SocialSignInConfig(googleServerClientId: 'web');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(androidOnly.isReady(google), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    // On iOS without its client id (and URL scheme) Google's SDK would end
    // the app: off.
    expect(androidOnly.isReady(google), isFalse);
    expect(androidOnly.offers(google), isFalse);
  });

  test('the development build shows them before they work', () {
    const config = SocialSignInConfig(showUnconfigured: true);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(config.offers(google), isTrue);
    expect(config.offers(apple), isTrue);
    expect(config.isReady(google), isFalse);
    expect(config.isReady(apple), isFalse);
  });
}

import 'dart:convert';
import 'dart:math';

import 'package:authentication_client/authentication_client.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Which "Continue with Google / Apple" sign-ins a build offers, and its ids.
///
/// The ids are not secrets (they are in every copy of the app). Until one is
/// set the sign-in stays off; the auth-service checks the tokens against the
/// same ids (GOOGLE_CLIENT_IDS, APPLE_CLIENT_IDS).
@immutable
class SocialSignInConfig {
  const SocialSignInConfig({
    this.googleServerClientId = '',
    this.googleIosClientId = '',
    this.apple = false,
    this.showUnconfigured = false,
  });

  /// Google's web client id: Android's ID tokens are for it.
  final String googleServerClientId;

  /// This build's iOS client id (made for its bundle id). iOS needs its
  /// reversed form as a URL scheme in Info.plist as well.
  final String googleIosClientId;

  /// Sign in with Apple is on for this build's bundle id.
  final bool apple;

  /// Development: the buttons show before it is all set up, to be seen; a
  /// tap then says the sign-in isn't available yet.
  final bool showUnconfigured;

  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Set up for this platform: a tap signs in.
  bool isReady(SocialProvider provider) => switch (provider) {
    SocialProvider.google =>
      (_ios && googleIosClientId.isNotEmpty) ||
          (_android && googleServerClientId.isNotEmpty),
    // Apple's own sheet on iPhone only: on Android it is a web sign-in, and
    // the App Store rule asking for it is the iPhone's.
    SocialProvider.apple => _ios && apple,
  };

  /// Its button shows on this phone.
  bool offers(SocialProvider provider) =>
      isReady(provider) ||
      (showUnconfigured &&
          switch (provider) {
            SocialProvider.google => _ios || _android,
            SocialProvider.apple => _ios,
          });
}

/// What Google or Apple gave the phone, for the auth-service to check.
typedef ProviderTokens = ({
  String idToken,
  String? nonce,
  String? authorizationCode,
  String fullName,
});

/// The phone's side of Google / Apple sign-in: their own sheets, which hand
/// back an ID token. Nothing here is trusted by the server as it is.
class SocialProviders {
  SocialProviders(this.config);

  final SocialSignInConfig config;

  Future<void>? _googleReady;

  /// Opens [provider]'s sheet. Throws [SocialSignInCanceled] when it is
  /// closed, else a [SocialSignInFailure].
  Future<ProviderTokens> signIn(SocialProvider provider) => switch (provider) {
    SocialProvider.google => _google(),
    SocialProvider.apple => _apple(),
  };

  Future<ProviderTokens> _google() async {
    final ready = _googleReady ??= GoogleSignIn.instance.initialize(
      clientId: config.googleIosClientId.isEmpty
          ? null
          : config.googleIosClientId,
      serverClientId: config.googleServerClientId.isEmpty
          ? null
          : config.googleServerClientId,
    );
    try {
      await ready;
    } catch (e, st) {
      // Tried again on the next tap.
      _googleReady = null;
      Error.throwWithStackTrace(SocialSignInFailure(e), st);
    }
    try {
      // The account picker every time, not the account signed in with
      // before (someone else on this phone, or another of theirs).
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialSignInFailure('Google gave no ID token.');
      }
      return (
        idToken: idToken,
        nonce: null,
        authorizationCode: null,
        fullName: account.displayName ?? '',
      );
    } on GoogleSignInException catch (e, st) {
      Error.throwWithStackTrace(
        e.code == GoogleSignInExceptionCode.canceled
            ? SocialSignInCanceled(e)
            : SocialSignInFailure(e),
        st,
      );
    } on AuthenticationException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(SocialSignInFailure(e), st);
    }
  }

  Future<ProviderTokens> _apple() async {
    // Made for this one sign-in; the token carries its hash, and the server
    // checks the two match (a token caught on the way can't be replayed).
    final nonce = randomNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const SocialSignInFailure('Apple gave no identity token.');
      }
      // Apple gives the name only the first time: the server keeps it then.
      final name = [credential.givenName, credential.familyName]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(' ');
      return (
        idToken: idToken,
        nonce: nonce,
        authorizationCode: credential.authorizationCode,
        fullName: name,
      );
    } on SignInWithAppleAuthorizationException catch (e, st) {
      Error.throwWithStackTrace(
        e.code == AuthorizationErrorCode.canceled
            ? SocialSignInCanceled(e)
            : SocialSignInFailure(e),
        st,
      );
    } on AuthenticationException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(SocialSignInFailure(e), st);
    }
  }

  /// 32 random characters, as Apple's nonce.
  @visibleForTesting
  static String randomNonce([Random? random]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = random ?? Random.secure();
    return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_authentication_client/firebase_authentication_client.dart';
// ignore: implementation_imports
import 'package:firebase_authentication_client/src/social_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:token_storage/token_storage.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockApi extends Mock implements AuthServiceApi {}

class _MockProviders extends Mock implements SocialProviders {}

class _MockPowerSync extends Mock implements PowerSyncRepository {}

/// Sign in with Google / Apple on the phone's side: what goes to the
/// auth-service and what comes of its answer. The server checks the tokens
/// (oci-backend/functions/auth-service/test/social.test.js).
void main() {
  late _MockFirebaseAuth auth;
  late _MockApi api;
  late _MockProviders providers;

  const ready = SocialSignInConfig(
    googleServerClientId: 'web-client',
    googleIosClientId: 'ios-client',
    apple: true,
  );

  const googleTokens = (
    idToken: 'google-id-token',
    nonce: null,
    authorizationCode: null,
    fullName: 'John Smith',
  );
  const appleTokens = (
    idToken: 'apple-id-token',
    nonce: 'raw-nonce',
    authorizationCode: 'apple-code',
    fullName: 'Jane Doe',
  );

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(SocialProvider.google);
  });

  setUp(() {
    auth = _MockFirebaseAuth();
    api = _MockApi();
    providers = _MockProviders();
    when(() => auth.idTokenChanges()).thenAnswer((_) => const Stream.empty());
    when(() => auth.currentUser).thenReturn(null);
    final credential = _MockUserCredential();
    when(() => credential.user).thenReturn(null);
    when(() => auth.signInWithCustomToken(any()))
        .thenAnswer((_) async => credential);
    when(() => providers.signIn(SocialProvider.google))
        .thenAnswer((_) async => googleTokens);
    when(() => providers.signIn(SocialProvider.apple))
        .thenAnswer((_) async => appleTokens);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AuthSession.instance.clear();
  });

  FirebaseAuthenticationClient client({
    SocialSignInConfig social = ready,
  }) => FirebaseAuthenticationClient(
    powerSyncRepository: _MockPowerSync(),
    firebaseAuth: auth,
    api: api,
    social: social,
    socialProviders: providers,
  );

  void answer(String path, Map<String, dynamic> body) => when(
    () => api.post(path, any(), bearer: any(named: 'bearer')),
  ).thenAnswer((_) async => body);

  Map<String, dynamic> sentTo(String path) =>
      verify(
            () => api.post(path, captureAny(), bearer: any(named: 'bearer')),
          ).captured.single
          as Map<String, dynamic>;

  test('a Google account with no account yet comes back as a ticket', () async {
    answer('/social/sign-in', {
      'needsUsername': true,
      'ticket': 'ticket-1',
      'suggestedUsername': 'johnsmith',
      'fullName': 'John Smith',
    });
    final result = await client().signInWithSocial(SocialProvider.google);

    expect(result, isA<SocialNeedsUsername>());
    result as SocialNeedsUsername;
    expect(result.ticket, 'ticket-1');
    expect(result.suggestedUsername, 'johnsmith');
    expect(sentTo('/social/sign-in'), containsPair('idToken', 'google-id-token'));
    // Not signed in yet: the account is made once a username is picked.
    verifyNever(() => auth.signInWithCustomToken(any()));
  });

  test('a known account signs in with the token it gets', () async {
    answer('/social/sign-in', {'token': 'custom-token', 'userId': 'u1'});
    final result = await client().signInWithSocial(SocialProvider.google);

    expect(result, isA<SocialSignedIn>());
    verify(() => auth.signInWithCustomToken('custom-token')).called(1);
  });

  test("Apple's sign-in sends its raw nonce and the name it gave", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    answer('/social/sign-in', {'token': 'custom-token'});
    await client().signInWithSocial(SocialProvider.apple);

    final body = sentTo('/social/sign-in');
    expect(body['provider'], 'apple');
    expect(body['idToken'], 'apple-id-token');
    expect(body['nonce'], 'raw-nonce');
    expect(body['fullName'], 'Jane Doe');
    expect(body.containsKey('authorizationCode'), isFalse);
  });

  test('not set up: no sheet opens, and it says so', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final c = client(social: const SocialSignInConfig(showUnconfigured: true));
    expect(c.isSocialSignInAvailable(SocialProvider.apple), isTrue);

    await expectLater(
      c.signInWithSocial(SocialProvider.apple),
      throwsA(
        isA<SocialSignInFailure>().having(
          (e) => (e.error as AuthServiceError).code,
          'code',
          'provider_unavailable',
        ),
      ),
    );
    verifyNever(() => providers.signIn(any()));
  });

  test('a closed sheet is a cancel, with nothing sent', () async {
    when(() => providers.signIn(SocialProvider.google))
        .thenThrow(const SocialSignInCanceled('closed'));
    await expectLater(
      client().signInWithSocial(SocialProvider.google),
      throwsA(isA<SocialSignInCanceled>()),
    );
    verifyNever(() => api.post(any(), any(), bearer: any(named: 'bearer')));
  });

  test("the service's refusal comes back with its code", () async {
    when(() => api.post('/social/complete', any(), bearer: any(named: 'bearer')))
        .thenThrow(
          const AuthServiceError(message: 'taken', code: 'username_taken'),
        );
    await expectLater(
      client().completeSocialSignUp(ticket: 't', username: 'johnsmith'),
      throwsA(
        isA<SocialSignInFailure>().having(
          (e) => (e.error as AuthServiceError).code,
          'code',
          'username_taken',
        ),
      ),
    );
  });

  test('the new account is made with the username, lower-cased', () async {
    answer('/social/complete', {'token': 'custom-token', 'isNew': true});
    await client().completeSocialSignUp(ticket: 't', username: 'JohnSmith ');

    expect(sentTo('/social/complete'), {'ticket': 't', 'username': 'johnsmith'});
    verify(() => auth.signInWithCustomToken('custom-token')).called(1);
  });

  group('signed in', () {
    setUp(() {
      AuthSession.instance.update(
        AuthTokens(
          idToken: 'session-id-token',
          accessToken: 'session-id-token',
          refreshToken: null,
          idTokenExpiry: DateTime.now().add(const Duration(hours: 1)),
          claims: const {'sub': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'},
        ),
      );
    });

    test('how the account signs in', () async {
      answer('/account/methods', {
        'password': false,
        'google': true,
        'apple': false,
      });
      final methods = await client().signInMethods();

      expect(methods, (password: false, google: true, apple: false));
      verify(
        () => api.post(
          '/account/methods',
          any(),
          bearer: 'session-id-token',
        ),
      ).called(1);
    });

    test('before a delete, Apple confirms it with its code, to revoke', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      answer('/social/reauth', {'ok': true});
      await client().confirmSocialSignIn(SocialProvider.apple, revoke: true);

      final captured = verify(
        () => api.post(
          '/social/reauth',
          captureAny(),
          bearer: captureAny(named: 'bearer'),
        ),
      ).captured;
      final body = captured[0] as Map<String, dynamic>;
      expect(captured[1], 'session-id-token');
      expect(body['idToken'], 'apple-id-token');
      expect(body['nonce'], 'raw-nonce');
      expect(body['authorizationCode'], 'apple-code');
      expect(body['revoke'], isTrue);
      // Only confirmed: the session isn't swapped for another one.
      verifyNever(() => auth.signInWithCustomToken(any()));
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:authentication_client/authentication_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_authentication_client/src/auth_service_api.dart';
import 'package:firebase_authentication_client/src/social_sign_in.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:token_storage/token_storage.dart';

/// {@template firebase_authentication_client}
/// A Firebase implementation of [AuthenticationClient] built on **custom
/// tokens** — the app owns every screen and no browser is involved.
///
/// Credentials are verified by the self-hosted `auth-service`, which mints a
/// Firebase custom token whose `uid` is the account's `profiles.id` UUID. The
/// app exchanges it via [FirebaseAuth.signInWithCustomToken], so the resulting
/// Firebase ID token has `sub == <UUID>` — the value PowerSync and PostgREST
/// validate, keeping `profiles.id` a real `uuid`.
///
/// Tokens are published to [AuthSession] (the backend-neutral session holder
/// `PowerSyncRepository` reads); its `userId` getter already prefers `oid` and
/// falls back to `sub`, so Firebase's `sub` flows through unchanged. Firebase
/// persists the session across restarts, so [restoreSession] just waits for the
/// SDK to rehydrate it.
/// {@endtemplate}
class FirebaseAuthenticationClient implements AuthenticationClient {
  /// {@macro firebase_authentication_client}
  FirebaseAuthenticationClient({
    required PowerSyncRepository powerSyncRepository,
    FirebaseAuth? firebaseAuth,
    AuthServiceApi? api,
    String authBaseUrl = 'https://api.treepnet.com/auth',
    SocialSignInConfig social = const SocialSignInConfig(),
    SocialProviders? socialProviders,
  }) : _powerSyncRepository = powerSyncRepository,
       _auth = firebaseAuth ?? FirebaseAuth.instance,
       _api = api ?? AuthServiceApi(baseUrl: authBaseUrl),
       _social = social,
       _providers = socialProviders ?? SocialProviders(social) {
    // Let PowerSyncRepository trigger a silent refresh without a dependency
    // cycle.
    AuthSession.instance.registerRefresher(_refresh);
    // Keep the session fresh: Firebase fires this on sign-in, sign-out and
    // every automatic token refresh.
    _sub = _auth.idTokenChanges().listen((user) async {
      if (user == null) {
        AuthSession.instance.clear();
      } else {
        try {
          await _publishOrSignOut(user);
        } catch (_) {
          // Transient refresh failures are left alone — the listener re-fires
          // on the next token refresh, and PowerSync keeps asking for one.
        }
      }
    });
  }

  final PowerSyncRepository _powerSyncRepository;
  final FirebaseAuth _auth;
  final AuthServiceApi _api;
  final SocialSignInConfig _social;
  final SocialProviders _providers;
  StreamSubscription<User?>? _sub;

  @override
  Stream<AuthenticationUser> get user async* {
    yield _toUser(AuthSession.instance.current);
    yield* AuthSession.instance.changes.map(_toUser);
  }

  /// Cancels the Firebase token listener. The client is an app-lifetime
  /// singleton so this is rarely called, but it keeps the subscription owned.
  Future<void> dispose() async => _sub?.cancel();

  // --- Session ------------------------------------------------------------

  /// Restores any persisted session so the app's first user read sees the
  /// signed-in state. Returns within about two seconds, even offline.
  ///
  /// The native SDK finishes rehydrating the persisted user during
  /// `Firebase.initializeApp()` (awaited before this runs), so `currentUser` is
  /// the authoritative check. `authStateChanges().first` is deliberately NOT
  /// used as the primary source: on a cold start its very first event can be a
  /// premature `null` (emitted before rehydration completes), and taking it
  /// dropped a valid session and stranded the user on the login screen after
  /// every restart. Fall back to the stream only if `currentUser` is somehow
  /// still null.
  ///
  /// A still-valid ID token comes from Firebase's cache at once. An expired
  /// one (the app was closed for over an hour) needs the network: that used
  /// to hold the splash for up to 10 s, and with no connection it failed and
  /// the app showed the login screen, although the account and its data are
  /// on the phone — and stayed there when the connection came back. Now, if
  /// the token isn't here within two seconds, the app opens signed in with
  /// what's on the phone ([_pendingTokens]) and the token arrives in the
  /// background. An account deleted or disabled on the server, or signed out
  /// everywhere by a password reset, is signed out once that's found out.
  Future<void> restoreSession() async {
    final user = _auth.currentUser ?? await _auth.authStateChanges().first;
    if (user == null) return;
    await _publishOrSignOut(user)
        .then((_) => true, onError: (Object _) => false)
        .timeout(const Duration(seconds: 2), onTimeout: () => false);
    if (AuthSession.instance.current == null && _auth.currentUser != null) {
      AuthSession.instance.update(_pendingTokens(user));
    }
  }

  /// The session of a signed-in [user] whose ID token isn't here yet. It names
  /// the user, and its token counts as expired, so whatever talks to the
  /// server fetches a real one first (`AuthSession.idToken`, PowerSync's
  /// `fetchCredentials`, which retries until the connection is back).
  AuthTokens _pendingTokens(User user) => AuthTokens(
    idToken: '',
    accessToken: '',
    refreshToken: user.refreshToken,
    idTokenExpiry: DateTime.fromMillisecondsSinceEpoch(0),
    claims: {'sub': user.uid},
  );

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await _publishOrSignOut(user, forceRefresh: true);
  }

  /// [_publish], but an account that can no longer get a token — deleted or
  /// disabled on the server, or signed out everywhere by a password reset
  /// (getIdToken throws e.g. firebase_auth/user-not-found) — is signed out
  /// instead of retried forever. Other failures (no connection) are rethrown
  /// and leave the session as it is.
  Future<void> _publishOrSignOut(User user, {bool forceRefresh = false}) async {
    try {
      await _publish(user, forceRefresh: forceRefresh);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('user-not-found') ||
          msg.contains('user-disabled') ||
          msg.contains('user-token-expired')) {
        AuthSession.instance.clear();
        try {
          await _auth.signOut();
        } catch (_) {}
        return;
      }
      rethrow;
    }
  }

  Future<void> _publish(User user, {bool forceRefresh = false}) async {
    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null) return;
    final claims = _decodeJwt(idToken);
    final expSeconds = (claims['exp'] as num?)?.toInt();
    AuthSession.instance.update(
      AuthTokens(
        idToken: idToken,
        accessToken: idToken,
        refreshToken: user.refreshToken,
        idTokenExpiry: expSeconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000),
        claims: claims,
      ),
    );
  }

  // --- Sign in ------------------------------------------------------------

  /// Signs in with a **username or email** ([email]) and [password] via the
  /// auth-service, then exchanges the returned custom token for a session.
  @override
  Future<void> logInWithPassword({
    required String password,
    String? email,
    String? phone,
  }) async {
    final identifier = email?.trim() ?? '';
    if (identifier.isEmpty) {
      throw const LogInWithPasswordCanceled('Enter your username or email.');
    }
    try {
      final res = await _api.post('/login', <String, dynamic>{
        'usernameOrEmail': identifier,
        'password': password,
      });
      await _signInWithCustomToken(res['token'] as String?);
    } on AuthenticationException {
      rethrow;
    } on AuthServiceError catch (error, stackTrace) {
      // Kept apart so the login screen can say what actually went wrong.
      Error.throwWithStackTrace(
        switch (error.code) {
          'invalid_credentials' => LogInWithPasswordInvalidCredentials(
            error.message,
          ),
          AuthServiceError.networkCode => LogInWithPasswordNetworkFailure(
            error.message,
          ),
          _ => LogInWithPasswordFailure(error.message),
        },
        stackTrace,
      );
    } on FirebaseAuthException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        error.code == 'network-request-failed'
            ? LogInWithPasswordNetworkFailure(error)
            : LogInWithPasswordFailure(error),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithPasswordFailure(error), stackTrace);
    }
  }

  // --- Sign up (three steps, driven by the UI) ----------------------------

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final rows = await _powerSyncRepository
        .postgrest()
        .from('profiles')
        .select('id')
        .eq('username', username.toLowerCase())
        .limit(1);
    return (rows as List).isEmpty;
  }

  @override
  Future<({String continuationToken, int codeLength})> signUpSendCode({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _api.post('/signup/send-code', <String, dynamic>{
        'email': email.trim(),
        'password': password,
        // The code email is written in it.
        'lang': AuthServiceApi.language,
      });
      return (
        continuationToken:
            (res['continuationToken'] as String?) ?? email.trim(),
        codeLength: (res['codeLength'] as num?)?.toInt() ?? 6,
      );
    } on AuthServiceError catch (error, stackTrace) {
      // Carry the error itself so the cubit can inspect `code` (a password
      // problem belongs back on the password screen).
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  @override
  Future<void> signUpVerifyCode({
    required String continuationToken,
    required String code,
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? birthday,
  }) async {
    try {
      final res = await _api.post('/signup/verify', <String, dynamic>{
        'email': email.trim(),
        'code': code,
        'username': username.toLowerCase(),
        'fullName': fullName,
        'password': password,
        if (birthday != null) 'birthday': birthday,
      });
      await _signInWithCustomToken(res['token'] as String?);
    } on AuthenticationException {
      rethrow;
    } on AuthServiceError catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SignUpWithPasswordFailure(error), stackTrace);
    }
  }

  // --- Password reset -----------------------------------------------------

  @override
  Future<({String continuationToken, int codeLength})> resetPasswordSendCode({
    required String usernameOrEmail,
  }) async {
    final identifier = usernameOrEmail.trim();
    if (identifier.isEmpty) {
      throw const ResetPasswordFailure('Enter your username or email.');
    }
    try {
      final res = await _api.post('/reset/send-code', <String, dynamic>{
        'usernameOrEmail': identifier,
        // The code email's language when the account has none on file.
        'lang': AuthServiceApi.language,
      });
      return (
        continuationToken: (res['continuationToken'] as String?) ?? '',
        codeLength: (res['codeLength'] as num?)?.toInt() ?? 6,
      );
    } on AuthServiceError catch (error, stackTrace) {
      // The error itself, not its English message: the app reads its code
      // (invalid_code, code_expired, email_failed, ...) to say what happened
      // in its own language.
      Error.throwWithStackTrace(ResetPasswordFailure(error), stackTrace);
    }
  }

  @override
  Future<void> resetPasswordSubmit({
    required String continuationToken,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _api.post('/reset/verify', <String, dynamic>{
        'continuationToken': continuationToken,
        'code': code,
        'newPassword': newPassword,
      });
    } on AuthServiceError catch (error, stackTrace) {
      // The error itself, not its English message: the app reads its code
      // (invalid_code, code_expired, email_failed, ...) to say what happened
      // in its own language.
      Error.throwWithStackTrace(ResetPasswordFailure(error), stackTrace);
    }
  }

  // --- Sign in with Google / Apple ----------------------------------------
  //
  // Google's or Apple's own sheet gives the phone an ID token; the
  // auth-service checks it (social.js) and answers as a password sign-in
  // does — a custom token for the account tied to it — or with a ticket for
  // a new account, made once a username is picked.

  @override
  bool isSocialSignInAvailable(SocialProvider provider) =>
      _social.offers(provider);

  /// Not set up for this build (the development build shows the button
  /// anyway): said, rather than opening a sheet that can't work — Google's
  /// on iOS would close the app without its URL scheme.
  void _requireReady(SocialProvider provider) {
    if (_social.isReady(provider)) return;
    throw const SocialSignInFailure(
      AuthServiceError(
        message: 'This sign-in is not available yet.',
        code: 'provider_unavailable',
      ),
    );
  }

  Map<String, dynamic> _tokenBody(SocialProvider provider, ProviderTokens t) =>
      <String, dynamic>{
        'provider': provider.name,
        'idToken': t.idToken,
        if (t.nonce != null) 'nonce': t.nonce,
        if (t.fullName.isNotEmpty) 'fullName': t.fullName,
      };

  /// [run], with anything but a cancel or a failure already said turned
  /// into a [SocialSignInFailure].
  Future<T> _socialCall<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on SocialSignInCanceled {
      rethrow;
    } on SocialSignInFailure {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(SocialSignInFailure(error), stackTrace);
    }
  }

  @override
  Future<SocialSignInResult> signInWithSocial(SocialProvider provider) =>
      _socialCall(() async {
        _requireReady(provider);
        final tokens = await _providers.signIn(provider);
        final res = await _api.post('/social/sign-in', <String, dynamic>{
          ..._tokenBody(provider, tokens),
          'lang': AuthServiceApi.language,
        });
        if (res['needsUsername'] == true) {
          final ticket = res['ticket'] as String?;
          if (ticket == null || ticket.isEmpty) {
            throw const SocialSignInFailure('No ticket returned from auth.');
          }
          return SocialNeedsUsername(
            ticket: ticket,
            suggestedUsername: res['suggestedUsername'] as String?,
            fullName: (res['fullName'] as String?) ?? '',
          );
        }
        await _signInWithCustomToken(res['token'] as String?);
        return const SocialSignedIn();
      });

  @override
  Future<void> completeSocialSignUp({
    required String ticket,
    required String username,
  }) => _socialCall(() async {
    final res = await _api.post('/social/complete', <String, dynamic>{
      'ticket': ticket,
      'username': username.trim().toLowerCase(),
    });
    await _signInWithCustomToken(res['token'] as String?);
  });

  /// The signed-in user's ID token, for a call about their account.
  Future<String> _bearer() async {
    final token = await AuthSession.instance.idToken();
    if (token == null || token.isEmpty) {
      throw const SocialSignInFailure(
        AuthServiceError(message: 'Sign in again.', code: 'unauthorized'),
      );
    }
    return token;
  }

  @override
  Future<SignInMethods> signInMethods() => _socialCall(() async {
    final res = await _api.post(
      '/account/methods',
      const <String, dynamic>{},
      bearer: await _bearer(),
    );
    return (
      password: res['password'] == true,
      google: res['google'] == true,
      apple: res['apple'] == true,
    );
  });

  @override
  Future<void> confirmSocialSignIn(
    SocialProvider provider, {
    bool revoke = false,
  }) => _socialCall(() async {
    _requireReady(provider);
    final bearer = await _bearer();
    final tokens = await _providers.signIn(provider);
    await _api.post(
      '/social/reauth',
      <String, dynamic>{
        ..._tokenBody(provider, tokens),
        if (tokens.authorizationCode != null)
          'authorizationCode': tokens.authorizationCode,
        'revoke': revoke,
      },
      bearer: bearer,
    );
  });

  // --- Sign out -----------------------------------------------------------

  @override
  Future<void> logOut() async {
    try {
      // Clear the session first so the UI routes to the auth page (cancelling
      // its open watches) before the database is wiped.
      AuthSession.instance.clear();
      await _auth.signOut();
      await _powerSyncRepository.db().disconnectAndClear();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogOutFailure(error), stackTrace);
    }
  }

  @override
  Future<void> deleteAuthUser() async {
    try {
      // Clear the session first so the UI routes away before the DB is wiped.
      AuthSession.instance.clear();
      try {
        await _auth.currentUser?.delete();
      } on FirebaseAuthException {
        // Couldn't delete the Firebase user (e.g. requires-recent-login). The
        // account's data is already gone server-side, so signing out is enough.
        await _auth.signOut();
      }
      await _powerSyncRepository.db().disconnectAndClear();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogOutFailure(error), stackTrace);
    }
  }

  // --- Helpers ------------------------------------------------------------

  Future<void> _signInWithCustomToken(String? token) async {
    if (token == null) {
      throw const LogInWithPasswordFailure('No token returned from auth.');
    }
    final credential = await _auth.signInWithCustomToken(token);
    final user = credential.user;
    if (user != null) await _publish(user, forceRefresh: true);
  }

  /// Whether [error] is a password complaint (belongs back on the password
  /// screen). The sign-up cubit calls it.
  /// Signs out a Firebase session left from an earlier install of the app
  /// (iOS keeps it in the Keychain, which survives deleting the app), without
  /// the server calls of a normal sign-out: nothing of this install is
  /// registered yet.
  static Future<void> signOutLeftoverSession() async {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  }

  static bool isPasswordProblem(Object error) {
    final inner = error is SignUpWithPasswordFailure ? error.error : error;
    if (inner is! AuthServiceError) return false;
    return inner.code?.startsWith('password') ?? false;
  }

  /// Turns an auth-service error into a message worth showing a person. The
  /// service already returns friendly text, so surface it directly.
  static String friendlyMessage(Object error) {
    final inner = error is SignUpWithPasswordFailure ? error.error : error;
    if (inner is AuthServiceError) return inner.message;
    return 'Something went wrong. Please try again.';
  }

  AuthenticationUser _toUser(AuthTokens? tokens) {
    if (tokens == null) return AuthenticationUser.anonymous;
    final claims = tokens.claims;
    return AuthenticationUser(
      id: tokens.userId,
      // Custom-token users carry no email/name claims; UserRepository merges
      // those from the `profiles` row.
      email: claims['email'] as String?,
      fullName: claims['name'] as String?,
      isNewUser: false,
    );
  }

  Map<String, dynamic> _decodeJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return <String, dynamic>{};
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}

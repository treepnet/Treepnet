import 'dart:async';
import 'dart:convert';

import 'package:authentication_client/authentication_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_authentication_client/src/auth_service_api.dart';
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
/// Tokens are published to [EntraSession] (the backend-neutral session holder
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
  })  : _powerSyncRepository = powerSyncRepository,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _api = api ?? AuthServiceApi(baseUrl: authBaseUrl) {
    // Let PowerSyncRepository trigger a silent refresh without a dependency
    // cycle, mirroring the Entra client.
    EntraSession.instance.registerRefresher(_refresh);
    // Keep the session fresh: Firebase fires this on sign-in, sign-out and
    // every automatic token refresh.
    _sub = _auth.idTokenChanges().listen((user) async {
      if (user == null) {
        EntraSession.instance.clear();
      } else {
        await _publish(user);
      }
    });
  }

  final PowerSyncRepository _powerSyncRepository;
  final FirebaseAuth _auth;
  final AuthServiceApi _api;
  StreamSubscription<User?>? _sub;

  @override
  Stream<AuthenticationUser> get user async* {
    yield _toUser(EntraSession.instance.current);
    yield* EntraSession.instance.changes.map(_toUser);
  }

  /// Cancels the Firebase token listener. The client is an app-lifetime
  /// singleton so this is rarely called, but it keeps the subscription owned.
  Future<void> dispose() async => _sub?.cancel();

  // --- Session ------------------------------------------------------------

  /// Waits for Firebase to rehydrate any persisted session, then publishes it
  /// so the app's first user read sees the signed-in state.
  Future<void> restoreSession() async {
    final user = await _auth.authStateChanges().first;
    if (user != null) await _publish(user);
  }

  Future<void> _refresh() async {
    final user = _auth.currentUser;
    if (user != null) await _publish(user, forceRefresh: true);
  }

  Future<void> _publish(User user, {bool forceRefresh = false}) async {
    final idToken = await user.getIdToken(forceRefresh);
    if (idToken == null) return;
    final claims = _decodeJwt(idToken);
    final expSeconds = (claims['exp'] as num?)?.toInt();
    EntraSession.instance.update(
      EntraTokens(
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
      Error.throwWithStackTrace(
        LogInWithPasswordFailure(error.message),
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
    required String fullName,
  }) async {
    try {
      final res = await _api.post('/signup/send-code', <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'fullName': fullName,
      });
      return (
        continuationToken: (res['continuationToken'] as String?) ?? email.trim(),
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

  /// Kept for the [AuthenticationClient] contract; Treepnet's sign-up is the
  /// three-step [signUpSendCode] / [signUpVerifyCode] flow instead.
  @override
  Future<void> signUpWithPassword({
    required String password,
    required String fullName,
    required String username,
    String? avatarUrl,
    String? email,
    String? phone,
    String? pushToken,
  }) async {
    throw UnsupportedError(
      'Use signUpSendCode/signUpVerifyCode for the native sign-up flow.',
    );
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
      });
      return (
        continuationToken: (res['continuationToken'] as String?) ?? '',
        codeLength: (res['codeLength'] as num?)?.toInt() ?? 6,
      );
    } on AuthServiceError catch (error, stackTrace) {
      Error.throwWithStackTrace(ResetPasswordFailure(error.message), stackTrace);
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
      Error.throwWithStackTrace(ResetPasswordFailure(error.message), stackTrace);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async => throw const SendPasswordResetEmailFailure(
    'Use resetPasswordSendCode for the native reset flow.',
  );

  @override
  Future<void> resetPassword({
    required String token,
    required String email,
    required String newPassword,
  }) async =>
      throw const ResetPasswordFailure('Password reset is not available yet.');

  // --- Unsupported providers ----------------------------------------------

  @override
  Future<void> logInWithGoogle() async =>
      throw const LogInWithGoogleFailure('Google sign-in is not enabled.');

  @override
  Future<void> logInWithGithub() async =>
      throw const LogInWithGithubFailure('GitHub sign-in is not enabled.');

  // --- Sign out -----------------------------------------------------------

  @override
  Future<void> logOut() async {
    try {
      // Clear the session first so the UI routes to the auth page (cancelling
      // its open watches) before the database is wiped.
      EntraSession.instance.clear();
      await _auth.signOut();
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
  /// screen). Mirrors the Entra client's helper the sign-up cubit calls.
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

  AuthenticationUser _toUser(EntraTokens? tokens) {
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

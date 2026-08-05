import 'dart:convert';

import 'package:authentication_client/authentication_client.dart';
import 'package:entra_authentication_client/src/entra_native_auth_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:shared/shared.dart' as shared;
import 'package:token_storage/token_storage.dart';

/// {@template entra_authentication_client}
/// A Microsoft Entra External ID implementation of [AuthenticationClient] built
/// on Entra's **native authentication** API — the app owns every screen and no
/// browser is involved.
///
/// Entra identifies users by email; Treepnet lets people sign in with their
/// **username**, so [logInWithPassword] resolves a username to its email via
/// the `profiles` table before authenticating.
///
/// Sign-up is a three-step flow driven by the UI: [signUpSendCode] (emails a
/// one-time code) then [signUpVerifyCode] (verifies, signs in, provisions the
/// profile).
///
/// Tokens are published to [EntraSession], which `PowerSyncRepository` reads to
/// authenticate sync and PostgREST writes. The refresh token is persisted in
/// secure storage so the session survives a restart via [restoreSession].
/// {@endtemplate}
class EntraAuthenticationClient implements AuthenticationClient {
  /// {@macro entra_authentication_client}
  EntraAuthenticationClient({
    required PowerSyncRepository powerSyncRepository,
    EntraNativeAuthApi? api,
    FlutterSecureStorage? secureStorage,
  }) : _powerSyncRepository = powerSyncRepository,
       _api =
           api ??
           EntraNativeAuthApi(
             clientId: clientId,
             tenantSubdomain: tenantSubdomain,
           ),
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    // Let PowerSyncRepository trigger a silent refresh without depending on
    // this client (avoids a dependency cycle).
    EntraSession.instance.registerRefresher(restoreSession);
  }

  /// Tenant subdomain of `treepnet.onmicrosoft.com`.
  static const tenantSubdomain = 'treepnet';

  /// Public client (mobile) application (client) id.
  static const clientId = '24510ac4-0d0a-47af-84ef-fd6c79e3ad9c';

  static const _refreshTokenKey = 'entra_refresh_token';

  final PowerSyncRepository _powerSyncRepository;
  final EntraNativeAuthApi _api;
  final FlutterSecureStorage _secureStorage;

  @override
  Stream<AuthenticationUser> get user async* {
    // A generator rather than a hand-built controller: the old version wired
    // `onCancel` to an async `sub.cancel()`, so a session change landing in
    // that window hit a controller that was already gone —
    // `Bad state: Cannot add event after closing`, thrown on every sign-out.
    yield _toUser(EntraSession.instance.current);
    yield* EntraSession.instance.changes.map(_toUser);
  }

  // --- Session ------------------------------------------------------------

  /// Silently restores a previous session from the persisted refresh token.
  Future<void> restoreSession() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) return;
    try {
      await _publish(await _api.refresh(refreshToken));
      try {
        await _ensureProfile();
      } catch (e, s) {
        shared.logE('EntraAuth: profile provisioning failed', error: e, stackTrace: s);
      }
    } catch (_) {
      await _secureStorage.delete(key: _refreshTokenKey);
    }
  }

  Future<void> _publish(Map<String, dynamic> payload) async {
    final idToken = payload['id_token'] as String?;
    final accessToken = payload['access_token'] as String?;
    if (idToken == null || accessToken == null) {
      throw const LogInWithPasswordFailure('No tokens returned from Entra.');
    }
    final expiresIn = (payload['expires_in'] as num?)?.toInt();
    EntraSession.instance.update(
      EntraTokens(
        idToken: idToken,
        accessToken: accessToken,
        refreshToken: payload['refresh_token'] as String?,
        idTokenExpiry: expiresIn == null
            ? null
            : DateTime.now().add(Duration(seconds: expiresIn)),
        claims: _decodeJwt(idToken),
      ),
    );
    final refreshToken = payload['refresh_token'] as String?;
    if (refreshToken != null) {
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  // --- Sign in ------------------------------------------------------------

  /// Signs in with a **username or email** ([email]) and [password].
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
      final address = identifier.contains('@')
          ? identifier
          : await _emailForUsername(identifier);
      await _publish(await _api.signIn(email: address, password: password));
      await _ensureProfile(email: address);
    } on AuthenticationException {
      rethrow;
    } on EntraAuthApiException catch (error, stackTrace) {
      final message = switch (error.subError) {
        'invalid_credentials' ||
        'invalid_grant' => 'Wrong username or password.',
        'user_not_found' => 'No account with that username.',
        _ => friendlyMessage(error),
      };
      Error.throwWithStackTrace(
        LogInWithPasswordFailure(message),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogInWithPasswordFailure(error), stackTrace);
    }
  }

  /// Resolves a username to the account's email via PostgREST, so people can
  /// sign in with the handle they chose rather than their address.
  Future<String> _emailForUsername(String username) async {
    final rows = await _powerSyncRepository
        .postgrest()
        .from('profiles')
        .select('email')
        .eq('username', username.toLowerCase())
        .limit(1);
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty || list.first['email'] == null) {
      throw const LogInWithPasswordFailure('No account with that username.');
    }
    return list.first['email'] as String;
  }

  // --- Sign up (three steps, driven by the UI) ----------------------------

  /// Whether [username] is still free. Used by the first sign-up screen.
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

  /// Step 2 → 3: creates the pending account and emails a one-time code.
  ///
  /// Returns the continuation token and the code length to render.
  @override
  Future<({String continuationToken, int codeLength})> signUpSendCode({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      return await _api.signUpSendCode(
        email: email.trim(),
        password: password,
        displayName: fullName,
      );
    } on EntraAuthApiException catch (error, stackTrace) {
      // Carry the API error itself, not just its text: the caller needs the
      // `suberror` to tell a password problem (which belongs on the password
      // screen) apart from an address problem.
      Error.throwWithStackTrace(
        SignUpWithPasswordFailure(error),
        stackTrace,
      );
    }
  }

  /// Whether [error] is Entra complaining about the password rather than the
  /// email — the person has to go back a screen to fix it.
  static bool isPasswordProblem(Object error) {
    final api = error is SignUpWithPasswordFailure ? error.error : error;
    if (api is! EntraAuthApiException) return false;
    return api.subError?.startsWith('password') ?? false;
  }

  /// Final step: verifies the emailed [code], signs the user in and provisions
  /// their `profiles` row with the details collected on the first screen.
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
      await _publish(
        await _api.signUpSubmitCode(
          continuationToken: continuationToken,
          code: code,
          password: password,
          displayName: fullName,
        ),
      );
      await _ensureProfile(
        email: email.trim(),
        fullName: fullName,
        username: username.toLowerCase(),
        birthday: birthday,
      );
    } on AuthenticationException {
      rethrow;
    } on EntraAuthApiException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        SignUpWithPasswordFailure(friendlyMessage(error)),
        stackTrace,
      );
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

  // --- Profile ------------------------------------------------------------

  /// Ensures a `profiles` row exists for the signed-in user. Idempotent.
  Future<void> _ensureProfile({
    String? email,
    String? fullName,
    String? username,
    String? birthday,
  }) async {
    final tokens = EntraSession.instance.current;
    if (tokens == null || tokens.userId.isEmpty) return;
    final userId = tokens.userId;
    final claims = tokens.claims;

    final db = _powerSyncRepository.db();
    final existing = await db.getOptional(
      'SELECT id FROM profiles WHERE id = ?',
      [userId],
    );
    if (existing != null) return;

    // The local database is empty on a fresh install, so "no local row" does
    // NOT mean "new account" — sync simply hasn't pulled the profile down yet.
    // Provisioning on that assumption wrote a second profile whose username
    // was derived from the email, and syncing it up clobbered the handle the
    // user had chosen. Ask the server before creating anything.
    try {
      final remote = await _powerSyncRepository
          .postgrest()
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .limit(1);
      if ((remote as List).isNotEmpty) {
        shared.logI('EntraAuth: profile already exists server-side, skipping');
        return;
      }
    } catch (error, stackTrace) {
      // Can't reach the server: do nothing rather than risk overwriting a
      // profile we simply failed to read.
      shared.logE(
        'EntraAuth: could not verify existing profile; skipping provisioning',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final resolvedEmail =
        email ?? (claims['email'] ?? claims['preferred_username']) as String?;
    final resolvedUsername =
        username ?? _deriveUsername(resolvedEmail, userId);

    await db.execute(
      '''
INSERT OR IGNORE INTO profiles(id, email, full_name, username, birthday)
VALUES(?, ?, ?, ?, ?)
''',
      [
        userId,
        resolvedEmail,
        fullName ?? claims['name'] as String?,
        resolvedUsername,
        birthday,
      ],
    );
    shared.logI('EntraAuth: provisioned profile for $resolvedUsername');
  }

  /// Derives a valid `profiles.username` from an email when one wasn't chosen.
  String _deriveUsername(String? source, String userId) {
    var u = (source ?? '')
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9_.]'), '');
    if (u.length > 20) u = u.substring(0, 20);
    if (u.length >= 3) return u;
    return 'user_${userId.replaceAll('-', '').substring(0, 8)}';
  }

  // --- Unsupported providers ----------------------------------------------

  @override
  Future<void> logInWithGoogle() async =>
      throw const LogInWithGoogleFailure('Google sign-in is not enabled.');

  @override
  Future<void> logInWithGithub() async =>
      throw const LogInWithGithubFailure('GitHub sign-in is not enabled.');

  @override
  Future<({String continuationToken, int codeLength})> resetPasswordSendCode({
    required String usernameOrEmail,
  }) async {
    final identifier = usernameOrEmail.trim();
    if (identifier.isEmpty) {
      throw const ResetPasswordFailure('Enter your username or email.');
    }
    try {
      // People sign in with either, so accept either here too.
      final address = identifier.contains('@')
          ? identifier
          : await _emailForUsername(identifier);
      return await _api.resetPasswordSendCode(email: address);
    } on AuthenticationException {
      rethrow;
    } on EntraAuthApiException catch (error, stackTrace) {
      final message = switch (error.subError) {
        'user_not_found' => 'No account with that username or email.',
        _ => friendlyMessage(error),
      };
      Error.throwWithStackTrace(ResetPasswordFailure(message), stackTrace);
    } catch (error, stackTrace) {
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
      await _api.resetPasswordSubmit(
        continuationToken: continuationToken,
        code: code,
        newPassword: newPassword,
      );
    } on EntraAuthApiException catch (error, stackTrace) {
      final message = switch (error.subError) {
        'invalid_oob_value' => 'That code is not right. Check it and retry.',
        'password_too_weak' ||
        'password_too_short' ||
        'password_banned' ||
        'password_recently_used' =>
          'Choose a stronger password.',
        _ => friendlyMessage(error),
      };
      Error.throwWithStackTrace(ResetPasswordFailure(message), stackTrace);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(ResetPasswordFailure(error), stackTrace);
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

  // --- Sign out -----------------------------------------------------------

  @override
  Future<void> logOut() async {
    try {
      // Order matters. Clearing the session first routes the UI to the auth
      // page, which cancels every `watch()` it had open; wiping the database
      // while those are still live makes them fire against a closing database
      // ("Bad state: Cannot add event after closing").
      EntraSession.instance.clear();
      await _secureStorage.delete(key: _refreshTokenKey);
      await _powerSyncRepository.db().disconnectAndClear();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(LogOutFailure(error), stackTrace);
    }
  }

  // --- Helpers ------------------------------------------------------------

  /// Turns an Entra API error into a message worth showing a person.
  ///
  /// The service reports real, actionable problems (a banned or weak password,
  /// an address already registered, a mistyped code) through `suberror`, so
  /// surface them instead of a generic failure.
  static String friendlyMessage(EntraAuthApiException e) {
    return switch (e.subError) {
      'password_banned' =>
        'Microsoft refused this password — it is on their banned list. Pick a '
            'different one: avoid common words, “treepnet”, and your own name.',
      'password_too_weak' ||
      'password_is_invalid' =>
        'That password was rejected. Avoid your name, your username and '
            'common words or sequences.',
      'password_too_short' => 'That password is too short.',
      'password_too_long' => 'That password is too long.',
      'password_recently_used' => 'That password was used recently.',
      'attribute_validation_failed' => 'Some details are invalid.',
      'invalid_oob_value' => 'That code is not right. Try again.',
      'user_already_exists' => 'An account with this email already exists.',
      'invalid_username' => 'That email address is not valid.',
      _ => e.description ?? 'Something went wrong. Please try again.',
    };
  }

  AuthenticationUser _toUser(EntraTokens? tokens) {
    if (tokens == null) return AuthenticationUser.anonymous;
    final claims = tokens.claims;
    return AuthenticationUser(
      id: tokens.userId,
      email: (claims['email'] ?? claims['preferred_username']) as String?,
      fullName: claims['name'] as String?,
      // Deliberately no username: Entra's `preferred_username` is the email
      // address, not the handle people choose here. The handle lives on the
      // `profiles` row, which UserRepository merges in.
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

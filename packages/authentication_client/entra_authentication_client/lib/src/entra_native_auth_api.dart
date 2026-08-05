import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared/shared.dart' as shared;

/// {@template entra_auth_api_exception}
/// An error returned by the Entra native authentication API.
///
/// The API uses 4xx responses for flow control as well as failures: e.g.
/// `credential_required` means "now send the password", and
/// `invalid_oob_value` means the user mistyped the emailed code. Inspect
/// [subError] to branch, and [continuationToken] to continue the flow.
/// {@endtemplate}
class EntraAuthApiException implements Exception {
  /// {@macro entra_auth_api_exception}
  const EntraAuthApiException({
    this.error,
    this.subError,
    this.description,
    this.continuationToken,
  });

  /// Top-level error code, e.g. `invalid_grant`.
  final String? error;

  /// Fine-grained code, e.g. `credential_required`, `invalid_oob_value`,
  /// `password_too_weak`, `user_already_exists`, `attributes_required`.
  final String? subError;

  /// Human-readable description from the service.
  final String? description;

  /// Token to continue the flow with, when the service supplies one.
  final String? continuationToken;

  @override
  String toString() =>
      'EntraAuthApiException(${error ?? '-'}/${subError ?? '-'}): '
      '${description ?? ''}';
}

/// {@template entra_native_auth_api}
/// Thin client over Microsoft Entra External ID's **native authentication**
/// REST API — the browser-free flow that lets the app own its sign-in and
/// sign-up UI.
///
/// Flutter has no MSAL SDK, so the documented HTTP API is used directly:
/// <https://learn.microsoft.com/entra/identity-platform/reference-native-authentication-api>
/// {@endtemplate}
class EntraNativeAuthApi {
  /// {@macro entra_native_auth_api}
  EntraNativeAuthApi({
    required this.clientId,
    required this.tenantSubdomain,
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Application (client) id of the native/public client.
  final String clientId;

  /// Tenant subdomain, e.g. `treepnet` for `treepnet.onmicrosoft.com`.
  final String tenantSubdomain;

  final Dio _dio;

  /// Scopes requested for the issued tokens. `openid` yields the id token used
  /// as the backend bearer; `offline_access` yields a refresh token.
  static const scopes = 'openid offline_access profile email';

  String get _base =>
      'https://$tenantSubdomain.ciamlogin.com/$tenantSubdomain.onmicrosoft.com';

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, String> form,
  ) async {
    // The endpoint drops connections now and then ("Software caused connection
    // abort") *after* it has already acted — a reset-password challenge would
    // email the code and still surface as a failure. Retry the transport a few
    // times so a dropped response doesn't strand the flow.
    late Response<Map<String, dynamic>> response;
    for (var attempt = 0; ; attempt++) {
      try {
        response = await _dio.post<Map<String, dynamic>>(
          url,
          data: form,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            // 4xx carries flow-control payloads, so read the body instead of
            // letting dio throw.
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        break;
      } on DioException catch (error) {
        final retryable =
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.unknown;
        if (!retryable || attempt >= 2) rethrow;
        shared.logI(
          'EntraNativeAuth: ${url.split('/').last} transport failure '
          '(${error.type.name}) — retrying',
        );
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    final data = response.data ?? const <String, dynamic>{};
    final status = response.statusCode ?? 500;
    if (status >= 400) {
      // 4xx is also how the service asks for the next credential, so log at
      // info: it is the only place the real reason (suberror) is visible.
      shared.logI(
        'EntraNativeAuth: ${url.split('/').last} → $status '
        '${data['error']}/${data['suberror']} — ${data['error_description']}',
      );
      throw EntraAuthApiException(
        error: data['error'] as String?,
        subError: data['suberror'] as String?,
        description: data['error_description'] as String?,
        continuationToken: data['continuation_token'] as String?,
      );
    }
    return data;
  }

  // --- Sign in ------------------------------------------------------------

  /// Signs in with [email] and [password], returning the token payload
  /// (`id_token`, `access_token`, `refresh_token`, `expires_in`).
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    final initiate = await _post('$_base/oauth2/v2.0/initiate', {
      'client_id': clientId,
      'challenge_type': 'password redirect',
      'username': email,
    });
    final challenge = await _post('$_base/oauth2/v2.0/challenge', {
      'client_id': clientId,
      'challenge_type': 'password redirect',
      'continuation_token': initiate['continuation_token'] as String,
    });
    return _post('$_base/oauth2/v2.0/token', {
      'client_id': clientId,
      'continuation_token': challenge['continuation_token'] as String,
      'grant_type': 'password',
      'password': password,
      'scope': scopes,
    });
  }

  // --- Sign up ------------------------------------------------------------

  /// Starts sign-up for [email] with [password] and emails a one-time code.
  ///
  /// Returns the continuation token to pass to [signUpSubmitCode], and the
  /// expected code length for the UI.
  Future<({String continuationToken, int codeLength})> signUpSendCode({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final start = await _post('$_base/signup/v1.0/start', {
      'client_id': clientId,
      'challenge_type': 'oob password redirect',
      'username': email,
      'password': password,
      if (displayName != null)
        'attributes': jsonEncode({'displayName': displayName}),
    });
    final challenge = await _post('$_base/signup/v1.0/challenge', {
      'client_id': clientId,
      'challenge_type': 'oob password redirect',
      'continuation_token': start['continuation_token'] as String,
    });
    return (
      continuationToken: challenge['continuation_token'] as String,
      codeLength: (challenge['code_length'] as num?)?.toInt() ?? 6,
    );
  }

  /// Submits the emailed [code] and completes sign-up, returning the token
  /// payload (the user is signed in immediately).
  ///
  /// [password] is resupplied because the service may ask for the credential
  /// only after the email is verified.
  Future<Map<String, dynamic>> signUpSubmitCode({
    required String continuationToken,
    required String code,
    required String password,
    String? displayName,
  }) async {
    var token = continuationToken;

    Future<void> submit(Map<String, String> extra) async {
      final response = await _post('$_base/signup/v1.0/continue', {
        'client_id': clientId,
        'continuation_token': token,
        ...extra,
      });
      token = response['continuation_token'] as String? ?? token;
    }

    try {
      await submit({'grant_type': 'oob', 'oob': code});
    } on EntraAuthApiException catch (e) {
      // The code was accepted but the service now wants the password and/or
      // attributes before it will finish.
      if (e.subError != 'credential_required' &&
          e.subError != 'attributes_required') {
        rethrow;
      }
      token = e.continuationToken ?? token;
    }

    // Supply whatever the service still asks for, in the order it asks.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _post('$_base/oauth2/v2.0/token', {
          'client_id': clientId,
          'continuation_token': token,
          'grant_type': 'continuation_token',
          'scope': scopes,
        });
      } on EntraAuthApiException catch (e) {
        token = e.continuationToken ?? token;
        if (e.subError == 'credential_required') {
          await submit({'grant_type': 'password', 'password': password});
        } else if (e.subError == 'attributes_required') {
          await submit({
            'grant_type': 'attributes',
            'attributes': jsonEncode({'displayName': displayName ?? 'Treepnet'}),
          });
        } else {
          rethrow;
        }
      }
    }
    throw const EntraAuthApiException(
      error: 'signup_incomplete',
      description: 'Sign-up did not complete after supplying credentials.',
    );
  }

  // --- Password reset -----------------------------------------------------

  /// Starts a password reset for [email] and emails a one-time code.
  ///
  /// Returns the continuation token to pass to [resetPasswordSubmit], plus the
  /// code length so the UI can size its input.
  Future<({String continuationToken, int codeLength})> resetPasswordSendCode({
    required String email,
  }) async {
    final start = await _post('$_base/resetpassword/v1.0/start', {
      'client_id': clientId,
      'challenge_type': 'oob redirect',
      'username': email,
    });
    final challenge = await _post('$_base/resetpassword/v1.0/challenge', {
      'client_id': clientId,
      'challenge_type': 'oob redirect',
      'continuation_token': start['continuation_token'] as String,
    });
    return (
      continuationToken: challenge['continuation_token'] as String,
      codeLength: (challenge['code_length'] as num?)?.toInt() ?? 6,
    );
  }

  /// Verifies the emailed [code] and sets [newPassword].
  ///
  /// The service applies the change asynchronously, so this polls until it
  /// reports success rather than returning while the old password still works.
  Future<void> resetPasswordSubmit({
    required String continuationToken,
    required String code,
    required String newPassword,
  }) async {
    final verified = await _post('$_base/resetpassword/v1.0/continue', {
      'client_id': clientId,
      'continuation_token': continuationToken,
      'grant_type': 'oob',
      'oob': code,
    });
    final submitted = await _post('$_base/resetpassword/v1.0/submit', {
      'client_id': clientId,
      'continuation_token': verified['continuation_token'] as String,
      'new_password': newPassword,
    });

    var token = submitted['continuation_token'] as String?;
    final wait = (submitted['poll_interval'] as num?)?.toInt() ?? 2;
    for (var attempt = 0; attempt < 12 && token != null; attempt++) {
      final poll = await _post('$_base/resetpassword/v1.0/poll_completion', {
        'client_id': clientId,
        'continuation_token': token,
      });
      switch (poll['status'] as String?) {
        case 'succeeded':
          return;
        case 'failed':
          throw EntraAuthApiException(
            error: 'password_reset_failed',
            description:
                (poll['error_description'] as String?) ??
                'The password could not be changed.',
          );
        default:
          token = poll['continuation_token'] as String? ?? token;
          await Future<void>.delayed(Duration(seconds: wait));
      }
    }
    throw const EntraAuthApiException(
      error: 'password_reset_timeout',
      description: 'The password change is taking too long. Try again.',
    );
  }

  // --- Token refresh ------------------------------------------------------

  /// Exchanges a [refreshToken] for a fresh token payload.
  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      _post('$_base/oauth2/v2.0/token', {
        'client_id': clientId,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'scope': scopes,
      });
}

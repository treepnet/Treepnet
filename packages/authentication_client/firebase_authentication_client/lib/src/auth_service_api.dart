import 'package:dio/dio.dart';

/// {@template auth_service_error}
/// An error returned by the Treepnet `auth-service`.
///
/// Carries the machine-readable [code] (e.g. `invalid_credentials`,
/// `password_too_short`, `username_taken`) alongside a human-friendly
/// [message] the UI can show directly, so the sign-up cubit can tell a password
/// problem (which belongs on the password screen) apart from other failures.
/// {@endtemplate}
class AuthServiceError implements Exception {
  /// {@macro auth_service_error}
  const AuthServiceError({required this.message, this.code});

  /// Human-friendly text (the service already localises-to-English for us).
  final String message;

  /// Machine-readable code, e.g. `invalid_credentials` or `password_too_short`.
  final String? code;

  @override
  String toString() => message;
}

/// {@template auth_service_api}
/// Thin HTTP client for the self-hosted `auth-service`
/// (`https://api.treepnet.com/auth/*`): the custom-token bridge that verifies
/// credentials and mints Firebase custom tokens.
/// {@endtemplate}
class AuthServiceApi {
  /// {@macro auth_service_api}
  AuthServiceApi({required this.baseUrl, Dio? dio}) : _dio = dio ?? _build();

  /// Base URL, e.g. `https://api.treepnet.com/auth` (no trailing slash).
  final String baseUrl;

  final Dio _dio;

  static Dio _build() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// POSTs [body] as JSON to [path] and returns the decoded response map.
  ///
  /// Throws [AuthServiceError] on a 4xx (structured `{error, code}`) or on a
  /// network/5xx failure (generic message).
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    const maxAttempts = 3;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // First try the shared client; on a connection failure retry on a FRESH
      // client, so a stale keep-alive / HTTP-2 connection can't fail every
      // attempt (the symptom: login works on a fresh connection, but a second
      // call reusing the pooled one fails).
      final dio = attempt == 0 ? _dio : _build();
      try {
        final res = await dio.post<dynamic>(
          '$baseUrl$path',
          data: body,
          options: Options(
            headers: <String, dynamic>{'Content-Type': 'application/json'},
            // Let us read 4xx bodies ({error, code}); only 5xx/network throw.
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final data = res.data is Map
            ? Map<String, dynamic>.from(res.data as Map)
            : <String, dynamic>{};
        final status = res.statusCode ?? 500;
        if (status >= 200 && status < 300) return data;
        throw AuthServiceError(
          message: (data['error'] as String?) ??
              'Something went wrong. Please try again.',
          code: data['code'] as String?,
        );
      } on DioException catch (e) {
        // A bad HTTP response (e.g. a 5xx, which comes back as badResponse) is a
        // real answer; only connection-level failures are worth retrying on a
        // fresh connection.
        final retriable = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown;
        if (!retriable || attempt == maxAttempts - 1) break;
        await Future<void>.delayed(
          Duration(milliseconds: 300 * (attempt + 1)),
        );
      }
    }
    throw const AuthServiceError(
      message: 'Network error. Please check your connection and try again.',
    );
  }
}

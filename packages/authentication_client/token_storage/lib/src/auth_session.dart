import 'dart:async';

/// {@template auth_tokens}
/// Immutable snapshot of the signed-in user's tokens (from Firebase
/// Authentication).
///
/// The [idToken] (audience == the Firebase project) is what PowerSync and the
/// self-hosted PostgREST validate, against Google's public keys.
/// {@endtemplate}
class AuthTokens {
  /// {@macro auth_tokens}
  const AuthTokens({
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.idTokenExpiry,
    required this.claims,
  });

  /// ID token — an RS256 JWT with `aud` == the Firebase project, `sub` == the
  /// user's id. Used as the bearer for PowerSync and PostgREST.
  final String idToken;

  /// OAuth access token (resource-scoped). Kept for completeness; not currently
  /// used as the backend bearer.
  final String accessToken;

  /// Refresh token used to obtain a fresh [idToken] silently.
  final String? refreshToken;

  /// Expiry of [idToken], if known.
  final DateTime? idTokenExpiry;

  /// Decoded claims of [idToken].
  final Map<String, dynamic> claims;

  /// Whether the [idToken] is still valid (with a 60s safety margin).
  bool get isIdTokenValid {
    final expiry = idTokenExpiry;
    if (expiry == null) return true;
    return DateTime.now().isBefore(
      expiry.subtract(const Duration(seconds: 60)),
    );
  }

  /// Stable user id — the profile id. Firebase puts it in `sub`; an `oid`
  /// claim (tokens of the sign-in used before Firebase) wins when present.
  String get userId =>
      (claims['oid'] as String?) ?? (claims['sub'] as String?) ?? '';
}

/// {@template auth_session}
/// Process-wide holder of the current sign-in session.
///
/// Written by the authentication client (on login / refresh / logout) and read
/// by `PowerSyncRepository` to authenticate PowerSync sync and PostgREST
/// writes — so the low-level repository needn't depend on the concrete auth
/// client (which would be a dependency cycle).
/// {@endtemplate}
class AuthSession {
  AuthSession._();

  /// Shared instance.
  static final AuthSession instance = AuthSession._();

  AuthTokens? _tokens;
  final StreamController<AuthTokens?> _controller =
      StreamController<AuthTokens?>.broadcast();

  Future<void> Function()? _refresher;

  /// The current tokens, or `null` when signed out.
  AuthTokens? get current => _tokens;

  /// Whether a session is currently held.
  bool get isAuthenticated => _tokens != null;

  /// Emits on every session change: the new tokens, or `null` on sign-out.
  Stream<AuthTokens?> get changes => _controller.stream;

  /// Registers the callback that performs a silent token refresh. The auth
  /// client owns the refresh implementation (it holds the AppAuth/refresh
  /// token); this indirection lets low-level readers trigger a refresh without
  /// depending on the auth client, avoiding a dependency cycle.
  void registerRefresher(Future<void> Function() refresher) =>
      _refresher = refresher;

  /// Triggers a silent token refresh via the registered [registerRefresher]
  /// callback, if any. On success [current] holds fresh tokens.
  Future<void> refresh() async => _refresher?.call();

  /// The current ID token, refreshed first when it is about to expire (or
  /// when [forceRefresh]); `null` when signed out, or when the app opened
  /// before it had one and it still couldn't be fetched. Throws when the
  /// refresh fails (e.g. no connection).
  Future<String?> idToken({bool forceRefresh = false}) async {
    var tokens = _tokens;
    if (tokens == null) return null;
    if (forceRefresh || !tokens.isIdTokenValid) {
      await refresh().timeout(const Duration(seconds: 10));
      tokens = _tokens;
    }
    final token = tokens?.idToken;
    return token == null || token.isEmpty ? null : token;
  }

  /// Replaces the current session and notifies listeners.
  void update(AuthTokens tokens) {
    _tokens = tokens;
    _controller.add(tokens);
  }

  /// Clears the session and notifies listeners.
  void clear() {
    _tokens = null;
    _controller.add(null);
  }
}

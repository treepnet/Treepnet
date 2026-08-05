import 'dart:async';

/// {@template entra_tokens}
/// Immutable snapshot of the tokens obtained from a Microsoft Entra External ID
/// OIDC exchange.
///
/// The [idToken] (audience == the app's client id) is what PowerSync and the
/// self-hosted PostgREST validate against Entra's JWKS, mirroring the role the
/// Supabase access token used to play.
/// {@endtemplate}
class EntraTokens {
  /// {@macro entra_tokens}
  const EntraTokens({
    required this.idToken,
    required this.accessToken,
    required this.refreshToken,
    required this.idTokenExpiry,
    required this.claims,
  });

  /// OIDC id token — an RS256 JWT with `aud` == client id, `iss` == the Entra
  /// tenant, `sub` == the stable user id. Used as the bearer for PowerSync and
  /// PostgREST.
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

  /// Stable user id. Prefers the `oid` (object id) claim, which is a GUID and
  /// therefore fits the Postgres `uuid` columns; falls back to `sub` (which in
  /// Entra External ID is a non-UUID pairwise identifier).
  String get userId =>
      (claims['oid'] as String?) ?? (claims['sub'] as String?) ?? '';
}

/// {@template entra_session}
/// Process-wide holder of the current Entra OIDC session.
///
/// Written by the authentication client (on login / refresh / logout) and read
/// by `PowerSyncRepository` to authenticate PowerSync sync and PostgREST
/// writes. This mirrors the global access `Supabase.instance.client.auth`
/// previously provided, decoupling the low-level repository from the concrete
/// auth client to avoid a dependency cycle.
/// {@endtemplate}
class EntraSession {
  EntraSession._();

  /// Shared instance.
  static final EntraSession instance = EntraSession._();

  EntraTokens? _tokens;
  final StreamController<EntraTokens?> _controller =
      StreamController<EntraTokens?>.broadcast();

  Future<void> Function()? _refresher;

  /// The current tokens, or `null` when signed out.
  EntraTokens? get current => _tokens;

  /// Whether a session is currently held.
  bool get isAuthenticated => _tokens != null;

  /// Emits on every session change: the new tokens, or `null` on sign-out.
  Stream<EntraTokens?> get changes => _controller.stream;

  /// Registers the callback that performs a silent token refresh. The auth
  /// client owns the refresh implementation (it holds the AppAuth/refresh
  /// token); this indirection lets low-level readers trigger a refresh without
  /// depending on the auth client, avoiding a dependency cycle.
  void registerRefresher(Future<void> Function() refresher) =>
      _refresher = refresher;

  /// Triggers a silent token refresh via the registered [registerRefresher]
  /// callback, if any. On success [current] holds fresh tokens.
  Future<void> refresh() async => _refresher?.call();

  /// Replaces the current session and notifies listeners.
  void update(EntraTokens tokens) {
    _tokens = tokens;
    _controller.add(tokens);
  }

  /// Clears the session and notifies listeners.
  void clear() {
    _tokens = null;
    _controller.add(null);
  }
}

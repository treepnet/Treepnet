import 'package:http/http.dart' as http;
import 'package:token_storage/token_storage.dart';

/// {@template fresh_token_client}
/// HTTP client for the PostgREST calls (RPCs such as search, account
/// deletion, referrals, and the upload queue's writes): each request is signed
/// with the current ID token, refreshed first when it's about to expire. When
/// signed out it goes as it is: without a token (the sign-up username check),
/// or with the one an upload began with.
///
/// The token used to be read when the client was made, expiry unchecked:
/// after an hour in the background the first such call got a 401.
/// {@endtemplate}
class FreshTokenClient extends http.BaseClient {
  /// {@macro fresh_token_client}
  FreshTokenClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  /// How long a call may take to answer. There was no limit: one stalled
  /// connection (Wi-Fi handing over to mobile) left the feed's next page
  /// loading for good, and the feed ignores page requests while one runs.
  static const timeout = Duration(seconds: 15);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Throws when a needed refresh fails (offline): the request couldn't
    // have succeeded with the expired token either.
    final token = await AuthSession.instance.idToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request).timeout(timeout);
  }

  @override
  void close() => _inner.close();
}

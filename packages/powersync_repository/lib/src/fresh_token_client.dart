import 'package:http/http.dart' as http;
import 'package:token_storage/token_storage.dart';

/// {@template fresh_token_client}
/// HTTP client for the PostgREST calls outside the upload queue (RPCs such as
/// search, account deletion, referrals): each request is signed with the
/// current ID token, refreshed first when it's about to expire, and goes out
/// without one when signed out (the sign-up username check).
///
/// The token used to be read when the client was made, expiry unchecked:
/// after an hour in the background the first such call got a 401.
/// {@endtemplate}
class FreshTokenClient extends http.BaseClient {
  /// {@macro fresh_token_client}
  FreshTokenClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Throws when a needed refresh fails (offline): the request couldn't
    // have succeeded with the expired token either.
    final token = await AuthSession.instance.idToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

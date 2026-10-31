import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:treepnet/l10n/l10n.dart';

/// The auth-service error code behind [error] (`invalid_code`,
/// `username_taken`, ...), [AuthServiceError.networkCode] when the service
/// couldn't be reached, or null when there's no telling.
String? authErrorCode(Object error) {
  if (error is LogInWithPasswordInvalidCredentials) {
    return 'invalid_credentials';
  }
  if (error is LogInWithPasswordNetworkFailure) {
    return AuthServiceError.networkCode;
  }
  final inner = error is AuthenticationException ? error.error : error;
  if (inner is AuthServiceError) return inner.code;
  final text = inner.toString();
  if (text.contains('DioException') ||
      text.contains('SocketException') ||
      text.contains('HttpException') ||
      text.contains('connection abort')) {
    return AuthServiceError.networkCode;
  }
  return null;
}

/// What to tell a person about a failed sign-up, password reset or account
/// deletion, in the app's language. The service's own messages are English
/// only, so they're never shown as they are.
String authErrorText(AppLocalizations l10n, Object error) =>
    authErrorTextFor(l10n, authErrorCode(error));

/// [authErrorText] for an error code already at hand.
String authErrorTextFor(AppLocalizations l10n, String? code) => switch (code) {
  'invalid_code' || 'invalid_oob_value' => l10n.otpInvalidErrorText,
  'code_expired' => l10n.authCodeExpiredText,
  'code_attempts' => l10n.authCodeAttemptsText,
  'user_already_exists' => l10n.emailAlreadyExistsText,
  'username_taken' => l10n.signUpUsernameTakenError,
  'invalid_username' => l10n.usernameValidationText,
  'invalid_email' => l10n.signUpInvalidEmailError,
  'password_too_short' => l10n.passwordLengthErrorText(8),
  'invalid_credentials' => l10n.incorrectCredentialsText,
  AuthServiceError.networkCode => l10n.networkProblemText,
  _ => l10n.signUpGenericError,
};

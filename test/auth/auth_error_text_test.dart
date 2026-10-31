import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/auth/auth_error_text.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Sign-up, reset and delete errors come back from the auth service with an
/// English message; the app shows its own text for each code instead.
void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  SignUpWithPasswordFailure failure(String code) => SignUpWithPasswordFailure(
    AuthServiceError(message: 'English', code: code),
  );

  test('each code has its own text, in the app language', () {
    expect(authErrorText(ru, failure('code_expired')), ru.authCodeExpiredText);
    expect(
      authErrorText(en, failure('code_attempts')),
      en.authCodeAttemptsText,
    );
    expect(authErrorText(ru, failure('invalid_code')), ru.otpInvalidErrorText);
    expect(
      authErrorText(ru, failure('user_already_exists')),
      ru.emailAlreadyExistsText,
    );
    expect(
      authErrorText(ru, failure('username_taken')),
      ru.signUpUsernameTakenError,
    );
  });

  test('the service English message is never shown', () {
    expect(authErrorText(ru, failure('something_new')), ru.signUpGenericError);
  });

  test('wrong password and no connection on account deletion', () {
    expect(
      authErrorText(ru, const LogInWithPasswordInvalidCredentials('x')),
      ru.incorrectCredentialsText,
    );
    expect(
      authErrorText(ru, const LogInWithPasswordNetworkFailure('x')),
      ru.networkProblemText,
    );
  });
}

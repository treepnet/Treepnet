import 'dart:async';

import 'package:authentication_client/src/models/models.dart';

/// {@template authentication_exception}
/// Exceptions from the authentication client.
/// {@endtemplate}
abstract class AuthenticationException implements Exception {
  /// {@macro authentication_exception}
  const AuthenticationException(this.error);

  /// The error which was caught.
  final Object error;

  @override
  String toString() => 'Authentication exception error: $error';
}

/// {@template log_in_with_password_failure}
/// Thrown during the sign in with password process if a failure occurs.
/// {@endtemplate}
class LogInWithPasswordFailure extends AuthenticationException {
  /// {@macro log_in_with_password_failure}
  const LogInWithPasswordFailure(super.error);
}

/// {@template log_in_with_password_invalid_credentials}
/// A [LogInWithPasswordFailure]: the username/email or password is wrong.
/// {@endtemplate}
class LogInWithPasswordInvalidCredentials extends LogInWithPasswordFailure {
  /// {@macro log_in_with_password_invalid_credentials}
  const LogInWithPasswordInvalidCredentials(super.error);
}

/// {@template log_in_with_password_network_failure}
/// A [LogInWithPasswordFailure]: the sign-in service couldn't be reached (no
/// connection or a timeout).
/// {@endtemplate}
class LogInWithPasswordNetworkFailure extends LogInWithPasswordFailure {
  /// {@macro log_in_with_password_network_failure}
  const LogInWithPasswordNetworkFailure(super.error);
}

/// {@template log_in_with_password_canceled}
/// Thrown during the sign in with password process if a cancel occurs.
/// {@endtemplate}
class LogInWithPasswordCanceled extends AuthenticationException {
  /// {@macro log_in_with_password_canceled}
  const LogInWithPasswordCanceled(super.error);
}

/// {@template sign_up_with_password_failure}
/// Thrown during the sign up with password process if a failure occurs.
/// {@endtemplate}
class SignUpWithPasswordFailure extends AuthenticationException {
  /// {@macro sign_up_with_password_failure}
  const SignUpWithPasswordFailure(super.error);
}

/// {@template reset_password_failure}
/// This exception is thrown when there is a failure during the reset password
/// process.
/// It indicates that the reset password operation was unsuccessful.
/// {@endtemplate}
class ResetPasswordFailure extends AuthenticationException {
  /// {@macro reset_password_failure}
  const ResetPasswordFailure(super.error);
}

/// {@template log_out_failure}
/// Thrown during the logout process if a failure occurs.
/// {@endtemplate}
class LogOutFailure extends AuthenticationException {
  /// {@macro log_out_failure}
  const LogOutFailure(super.error);
}

/// A generic Authentication Client Interface.
abstract class AuthenticationClient {
  /// Stream of [AuthenticationUser] which will emit the current user when
  /// the authentication state changes.
  ///
  /// Emits [AuthenticationUser.anonymous] if the user is not authenticated.
  Stream<AuthenticationUser> get user;

  /// Signs in with the provided [email] and [password].
  ///
  /// Throws a [LogInWithPasswordFailure] if an exception occurs.
  Future<void> logInWithPassword({
    required String password,
    String? email,
    String? phone,
  });

  /// Whether [username] is still free to claim.
  Future<bool> isUsernameAvailable(String username);

  /// Starts a code-based sign-up: registers the pending account and emails a
  /// one-time code.
  ///
  /// Returns the token used to continue the flow and the length of the code to
  /// render. Throws a [SignUpWithPasswordFailure] if an exception occurs.
  Future<({String continuationToken, int codeLength})> signUpSendCode({
    required String email,
    required String password,
  });

  /// Completes a code-based sign-up: verifies the emailed [code], signs the
  /// user in and provisions their profile.
  ///
  /// Throws a [SignUpWithPasswordFailure] if an exception occurs.
  Future<void> signUpVerifyCode({
    required String continuationToken,
    required String code,
    required String email,
    required String password,
    required String username,
    required String fullName,
    String? birthday,
  });

  /// Starts a password reset for [usernameOrEmail] and emails a one-time code.
  ///
  /// Returns the token used to continue the flow and the length of the code to
  /// render. Throws a [ResetPasswordFailure] if an exception occurs.
  Future<({String continuationToken, int codeLength})> resetPasswordSendCode({
    required String usernameOrEmail,
  });

  /// Completes a password reset: verifies the emailed [code] and sets
  /// [newPassword].
  ///
  /// Throws a [ResetPasswordFailure] if an exception occurs.
  Future<void> resetPasswordSubmit({
    required String continuationToken,
    required String code,
    required String newPassword,
  });

  /// Signs out the current user which will emit
  /// [AuthenticationUser.anonymous] from the [user] Stream.
  ///
  /// Throws a [LogOutFailure] if an exception occurs.
  Future<void> logOut();

  /// Deletes the currently authenticated identity from the auth provider and
  /// ends the session (emitting [AuthenticationUser.anonymous]). Called after
  /// the account's data has been removed server-side, so it is best-effort:
  /// falls back to a plain sign-out if the delete cannot complete.
  Future<void> deleteAuthUser();
}

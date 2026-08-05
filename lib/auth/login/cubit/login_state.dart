part of 'login_cubit.dart';

/// [LoginErrorMessage] is a type alias for [String] that is used to indicate
/// error message, that will be shown to user, when he will try to submit login
/// form, but there is an error occurred. It is used to show user, what exactly
/// went wrong.
typedef LoginErrorMessage = String;

/// [LoginState] submission status, indicating current state of user login
/// process.
enum LogInSubmissionStatus {
  /// [LogInSubmissionStatus.idle] indicates that user has not yet submitted
  /// login form.
  idle,

  /// [LogInSubmissionStatus.loading] indicates that user has submitted
  /// login form and is currently waiting for response from backend.
  loading,

  /// [LogInSubmissionStatus.googleAuthInProgress] indicates that user has
  /// submitted login with google.
  googleAuthInProgress,

  /// [LogInSubmissionStatus.githubAuthInProgress] indicates that user has
  /// submitted login with github.
  githubAuthInProgress,

  /// [LogInSubmissionStatus.success] indicates that user has successfully
  /// submitted login form and is currently waiting for response from backend.
  success,

  /// [LogInSubmissionStatus.invalidCredentials] indicates that user has
  /// submitted login form with invalid credentials.
  invalidCredentials,

  /// [LogInSubmissionStatus.userNotFound] indicates that user with provided
  /// credentials was not found in database.
  userNotFound,

  /// [LogInSubmissionStatus.loading] indicates that user has no internet
  /// connection,during network request.
  networkError,

  /// [LogInSubmissionStatus.error] indicates that something unexpected happen.
  error,

  /// [LogInSubmissionStatus.googleLogInFailure] indicates that some went
  /// wrong during google login process.
  googleLogInFailure;

  bool get isSuccess => this == LogInSubmissionStatus.success;
  bool get isLoading => this == LogInSubmissionStatus.loading;
  bool get isGoogleAuthInProgress =>
      this == LogInSubmissionStatus.googleAuthInProgress;
  bool get isGithubAuthInProgress =>
      this == LogInSubmissionStatus.githubAuthInProgress;
  bool get isInvalidCredentials =>
      this == LogInSubmissionStatus.invalidCredentials;
  bool get isNetworkError => this == LogInSubmissionStatus.networkError;
  bool get isUserNotFound => this == LogInSubmissionStatus.userNotFound;
  bool get isError =>
      this == LogInSubmissionStatus.error ||
      isUserNotFound ||
      isNetworkError ||
      isInvalidCredentials;
}

/// {@template login_state}
/// [LoginState] holds all the information related to user login process.
/// It is used to determine current state of user login process.
/// {@endtemplate}
class LoginState {
  /// {@macro login_state}
  const LoginState._({
    required this.status,
    required this.message,
    required this.showPassword,
    required this.username,
    required this.password,
  });

  /// Initial login state.
  const LoginState.initial()
    : this._(
        status: LogInSubmissionStatus.idle,
        message: '',
        showPassword: false,
        username: const Username.pure(),
        password: const Password.pure(),
      );

  final LogInSubmissionStatus status;

  /// People sign in with the handle they chose; the auth client resolves it to
  /// the account's email before authenticating.
  final Username username;
  final Password password;
  final bool showPassword;
  final LoginErrorMessage message;

  LoginState copyWith({
    LogInSubmissionStatus? status,
    LoginErrorMessage? message,
    bool? showPassword,
    Username? username,
    Password? password,
  }) {
    return LoginState._(
      status: status ?? this.status,
      message: message ?? this.message,
      showPassword: showPassword ?? this.showPassword,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

// Login error copy is localized at the point of display; see
// `login_form.dart` which maps [LogInSubmissionStatus] to `context.l10n`.

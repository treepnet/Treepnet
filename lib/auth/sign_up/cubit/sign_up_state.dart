// ignore_for_file: public_member_api_docs, sort_constructors_first
part of 'sign_up_cubit.dart';

/// Message that will be shown to user, when he will try to submit signup form,
/// but there is an error occurred. It is used to show user, what exactly went
/// wrong.
typedef SingUpErrorMessage = String;

/// Defines possible signup submission statuses. It is used to manipulate with
/// state, using Bloc, according to state. Therefore, when [success] we
/// can simply navigate user to main page and such.
enum SignUpSubmissionStatus {
  /// [SignUpSubmissionStatus.idle] indicates that user has not yet submitted
  /// signup form.
  idle,

  /// [SignUpSubmissionStatus.inProgress] indicates that user has submitted
  /// signup form and is currently waiting for response from backend.
  inProgress,

  /// [SignUpSubmissionStatus.success] indicates that user has successfully
  /// submitted signup form and is currently waiting for response from backend.
  success,

  /// [SignUpSubmissionStatus.emailAlreadyRegistered] indicates that email,
  /// provided by user, is occupied by another one in database.
  emailAlreadyRegistered,

  /// [SignUpSubmissionStatus.inProgress] indicates that user had no internet
  /// connection during network request.
  networkError,

  /// [SignUpSubmissionStatus.error] indicates something went wrong when user
  /// tried to sign up.
  error;

  bool get isSuccess => this == SignUpSubmissionStatus.success;
  bool get isLoading => this == SignUpSubmissionStatus.inProgress;
  bool get isEmailRegistered =>
      this == SignUpSubmissionStatus.emailAlreadyRegistered;
  bool get isNetworkError => this == SignUpSubmissionStatus.networkError;
  bool get isError =>
      this == SignUpSubmissionStatus.error ||
      isNetworkError ||
      isEmailRegistered;
}

/// {@template signup_state}
/// Defines signup state. It is used to store all the data, that is needed
/// for signup form to work properly. It also stores signup submission status,
/// that is used to manipulate with state, using Bloc, according to state.
/// {@endtemplate}
/// Why a sign-up step was rejected locally. The cubit has no `BuildContext`,
/// so it reports a cause and the screen renders it in the current language.
enum SignUpError {
  /// One or more fields on the screen are invalid.
  invalidFields,

  /// The chosen username already belongs to someone.
  usernameTaken,

  /// The email address is not a valid address.
  invalidEmail,

  /// The one-time code is empty or malformed.
  invalidCode,

  /// The password would be refused by the identity service.
  weakPassword,
}

/// The three screens of the sign-up flow, in order.
enum SignUpStep {
  /// Username, full name and password.
  details,

  /// Email address — submitting it sends the one-time code.
  email,

  /// The code that arrived by email; verifying it completes sign-up.
  code,
}

class SignupState extends Equatable {
  const SignupState._({
    required this.fullName,
    required this.email,
    required this.password,
    required this.username,
    required this.userProfileAvatarUrl,
    required this.submissionStatus,
    required this.showPassword,
    required this.step,
    required this.code,
    this.continuationToken,
    this.codeLength = 6,
    this.errorMessage,
    this.error,
  });

  /// Creates initial signup state. It is used to define initial state in
  /// [SignUpCubit].
  const SignupState.initial()
    : this._(
        fullName: const FullName.pure(),
        email: const Email.pure(),
        password: const Password.pure(),
        username: const Username.pure(),
        userProfileAvatarUrl: '',
        submissionStatus: SignUpSubmissionStatus.idle,
        showPassword: false,
        step: SignUpStep.details,
        code: const Otp.pure(),
      );

  /// Which screen of the flow is showing.
  final SignUpStep step;

  /// The emailed one-time code.
  final Otp code;

  /// Token that ties the three sign-up requests together, from `signUpSendCode`.
  final String? continuationToken;

  /// How many digits the emailed code has.
  final int codeLength;

  /// Text supplied by the identity service (already human-readable) when the
  /// backend rejected the step — e.g. the password was refused.
  final String? errorMessage;

  /// Locally-detected cause, rendered by the screen in the current language.
  final SignUpError? error;

  /// Email value state.
  final Email email;

  /// Password value state.
  final Password password;

  /// Stores full fullName valid and value state.
  final FullName fullName;

  /// Stores username valid and value state.
  final Username username;

  /// Sign up submission status state.
  final SignUpSubmissionStatus submissionStatus;

  /// Stores profile picture value state.
  final String? userProfileAvatarUrl;

  /// Defines if password is visible or not.
  final bool showPassword;

  /// Creates copy of current state with some fields updated.
  SignupState copyWith({
    Email? email,
    Password? password,
    FullName? fullName,
    Username? username,
    String? userProfileAvatarUrl,
    SignUpSubmissionStatus? submissionStatus,
    bool? showPassword,
    SignUpStep? step,
    Otp? code,
    String? continuationToken,
    int? codeLength,
    String? errorMessage,
    SignUpError? error,
  }) => SignupState._(
    email: email ?? this.email,
    password: password ?? this.password,
    fullName: fullName ?? this.fullName,
    username: username ?? this.username,
    userProfileAvatarUrl: userProfileAvatarUrl ?? this.userProfileAvatarUrl,
    submissionStatus: submissionStatus ?? this.submissionStatus,
    showPassword: showPassword ?? this.showPassword,
    step: step ?? this.step,
    code: code ?? this.code,
    continuationToken: continuationToken ?? this.continuationToken,
    codeLength: codeLength ?? this.codeLength,
    // Not `??` — a new step must be able to clear a stale error.
    errorMessage: errorMessage,
    error: error,
  );

  @override
  List<Object?> get props => <Object?>[
    email,
    password,
    fullName,
    username,
    userProfileAvatarUrl,
    submissionStatus,
    showPassword,
    step,
    code,
    continuationToken,
    codeLength,
    errorMessage,
    error,
  ];
}

// Sign-up error copy is localized at the point of display; see
// `sign_up_form.dart` which maps [SignUpSubmissionStatus] to `context.l10n`.

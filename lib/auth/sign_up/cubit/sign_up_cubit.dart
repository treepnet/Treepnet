
import 'package:bloc/bloc.dart';
import 'package:entra_authentication_client/entra_authentication_client.dart'
    show
        EntraAuthApiException,
        EntraAuthenticationClient,
        SignUpWithPasswordFailure;
import 'package:equatable/equatable.dart';
import 'package:form_fields/form_fields.dart';
import 'package:treepnet/auth/sign_up/widgets/password_strength_meter.dart';
import 'package:user_repository/user_repository.dart';

part 'sign_up_state.dart';

/// {@template sign_up_cubit}
/// Cubit for sign up state management. It is used to change signup state from
/// initial to in progress, success or error. It also validates email, password,
/// name, surname and phone number fields.
/// {@endtemplate}
class SignUpCubit extends Cubit<SignupState> {
  /// {@macro sign_up_cubit}
  SignUpCubit({
    required UserRepository userRepository,
  }) : _userRepository = userRepository,
       super(const SignupState.initial());

  final UserRepository _userRepository;

  /// Changes password visibility, making it visible or not.
  void changePasswordVisibility() =>
      emit(state.copyWith(showPassword: !state.showPassword));

  /// Emits initial state of signup screen. It is used to reset state.
  void resetState() => emit(const SignupState.initial());

  /// [Email] value was changed, triggering new changes in state. Checking
  /// whether or not value is valid in [Email] and emmiting new [Email]
  /// validation state.
  void onEmailChanged(String newValue) {
    final previousScreenState = state;
    final previousEmailState = previousScreenState.email;
    final shouldValidate = previousEmailState.invalid;
    final newEmailState = shouldValidate
        ? Email.dirty(newValue)
        : Email.pure(newValue);

    final newScreenState = state.copyWith(email: newEmailState);

    emit(newScreenState);
  }

  /// [Email] field was unfocused, here is checking if previous state
  /// with [Email] was valid, in order to indicate it in state after unfocus.
  void onEmailUnfocused() {
    final previousScreenState = state;
    final previousEmailState = previousScreenState.email;
    final previousEmailValue = previousEmailState.value;

    final newEmailState = Email.dirty(previousEmailValue);
    final newScreenState = previousScreenState.copyWith(email: newEmailState);
    emit(newScreenState);
  }

  /// [Password] value was changed, triggering new changes in state. Checking
  /// whether or not value is valid in [Password] and emmiting new [Password]
  /// validation state.
  void onPasswordChanged(String newValue) {
    final previousScreenState = state;
    final previousPasswordState = previousScreenState.password;
    final shouldValidate = previousPasswordState.invalid;
    final newPasswordState = shouldValidate
        ? Password.dirty(newValue)
        : Password.pure(newValue);

    final newScreenState = state.copyWith(password: newPasswordState);

    emit(newScreenState);
  }

  void onPasswordUnfocused() {
    final previousScreenState = state;
    final previousPasswordState = previousScreenState.password;
    final previousPasswordValue = previousPasswordState.value;

    final newPasswordState = Password.dirty(previousPasswordValue);
    final newScreenState = previousScreenState.copyWith(
      password: newPasswordState,
    );
    emit(newScreenState);
  }

  /// [FullName] value was changed, triggering new changes in state. Checking
  /// whether or not value is valid in [FullName] and emmiting new [FullName]
  /// validation state.
  void onFullNameChanged(String newValue) {
    final previousScreenState = state;
    final previousFullNameState = previousScreenState.fullName;
    final shouldValidate = previousFullNameState.invalid;
    final newFullNameState = shouldValidate
        ? FullName.dirty(newValue)
        : FullName.pure(newValue);

    final newScreenState = state.copyWith(fullName: newFullNameState);

    emit(newScreenState);
  }

  /// [FullName] field was unfocused, here is checking if previous state with
  /// [FullName] was valid, in order to indicate it in state after unfocus.
  void onFullNameUnfocused() {
    final previousScreenState = state;
    final previousFullNameState = previousScreenState.fullName;
    final previousFullNameValue = previousFullNameState.value;

    final newFullNameState = FullName.dirty(previousFullNameValue);
    final newScreenState = previousScreenState.copyWith(
      fullName: newFullNameState,
    );
    emit(newScreenState);
  }

  /// [Username] value was changed, triggering new changes in state. Checking
  /// whether or not value is valid in [Username] and emmiting new [Username]
  /// validation state.
  void onUsernameChanged(String newValue) {
    final previousScreenState = state;
    final previousUsernameState = previousScreenState.username;
    final shouldValidate = previousUsernameState.invalid;
    final newSurnameState = shouldValidate
        ? Username.dirty(newValue)
        : Username.pure(newValue);

    final newScreenState = state.copyWith(username: newSurnameState);

    emit(newScreenState);
  }

  void onUsernameUnfocused() {
    final previousScreenState = state;
    final previousUsernameState = previousScreenState.username;
    final previousUsernameValue = previousUsernameState.value;

    final newUsernameState = Username.dirty(previousUsernameValue);
    final newScreenState = previousScreenState.copyWith(
      username: newUsernameState,
    );
    emit(newScreenState);
  }

  /// The emailed one-time code, typed on the last screen.
  void onCodeChanged(String newValue) =>
      emit(state.copyWith(code: Otp.dirty(newValue.trim())));

  /// Returns to the previous screen of the flow.
  void backStep() {
    final previous = switch (state.step) {
      SignUpStep.code => SignUpStep.email,
      SignUpStep.email => SignUpStep.details,
      SignUpStep.details => SignUpStep.details,
    };
    emit(
      state.copyWith(
        step: previous,
        submissionStatus: SignUpSubmissionStatus.idle,
      ),
    );
  }

  /// Screen 1 → 2. Validates the details and checks the username is free.
  Future<void> submitDetails() async {
    final password = Password.dirty(state.password.value);
    final username = Username.dirty(state.username.value.trim());
    // Full name is NOT validated: the field was taken out of the form, so it
    // is always empty — and an empty FullName is invalid, which silently
    // failed every Continue tap.
    final isFormValid = FormzValid([password, username]).isFormValid;

    emit(state.copyWith(password: password, username: username));

    if (!isFormValid) {
      _fail(SignUpError.invalidFields);
      return;
    }

    // Entra rejects anything weaker, so stop here rather than after a round
    // trip: the meter under the field already shows why.
    if (!PasswordStrength.of(password.value).isAcceptable) {
      _fail(SignUpError.weakPassword);
      return;
    }

    emit(state.copyWith(submissionStatus: SignUpSubmissionStatus.inProgress));
    try {
      final isFree = await _userRepository.isUsernameAvailable(username.value);
      if (isClosed) return;
      if (!isFree) {
        _fail(SignUpError.usernameTaken);
        return;
      }
      emit(
        state.copyWith(
          step: SignUpStep.email,
          submissionStatus: SignUpSubmissionStatus.idle,
        ),
      );
    } catch (e, stackTrace) {
      _errorFormatter(e, stackTrace);
    }
  }

  /// Screen 2 → 3. Registers the pending account and emails the code.
  Future<void> submitEmail() async {
    final email = Email.dirty(state.email.value.trim());
    emit(state.copyWith(email: email));
    if (!FormzValid([email]).isFormValid) {
      _fail(SignUpError.invalidEmail);
      return;
    }

    emit(state.copyWith(submissionStatus: SignUpSubmissionStatus.inProgress));
    try {
      final result = await _userRepository.signUpSendCode(
        email: email.value,
        password: state.password.value,
        // The form no longer asks for a name, so the handle stands in as the
        // display name rather than sending Entra an empty string.
        fullName: state.fullName.value.trim().isEmpty
            ? state.username.value.trim()
            : state.fullName.value.trim(),
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          step: SignUpStep.code,
          continuationToken: result.continuationToken,
          codeLength: result.codeLength,
          submissionStatus: SignUpSubmissionStatus.idle,
        ),
      );
    } catch (e, stackTrace) {
      // The password only reaches Entra now, so its verdict lands on this
      // screen. Send people back to the field they must actually change —
      // Microsoft also refuses passwords that merely look strong.
      if (EntraAuthenticationClient.isPasswordProblem(e)) {
        addError(e, stackTrace);
        emit(
          state.copyWith(
            step: SignUpStep.details,
            submissionStatus: SignUpSubmissionStatus.error,
            errorMessage: _describe(e),
          ),
        );
        return;
      }
      _errorFormatter(e, stackTrace);
    }
  }

  /// Final screen. Verifies the code, signs in and provisions the profile.
  Future<void> submitCode() async {
    final code = Otp.dirty(state.code.value.trim());
    final token = state.continuationToken;
    emit(state.copyWith(code: code));
    if (token == null || !FormzValid([code]).isFormValid) {
      _fail(SignUpError.invalidCode);
      return;
    }

    emit(state.copyWith(submissionStatus: SignUpSubmissionStatus.inProgress));
    try {
      await _userRepository.signUpVerifyCode(
        continuationToken: token,
        code: code.value,
        email: state.email.value.trim(),
        password: state.password.value,
        username: state.username.value.trim(),
        fullName: state.fullName.value.trim(),
      );
      if (isClosed) return;
      emit(state.copyWith(submissionStatus: SignUpSubmissionStatus.success));
    } catch (e, stackTrace) {
      _errorFormatter(e, stackTrace);
    }
  }

  /// Surfaces why a step failed. The auth client already translates Entra's
  /// codes (banned password, address taken, wrong code) into readable text, so
  /// carry that through to the screen rather than showing a generic failure.
  void _errorFormatter(Object e, StackTrace stackTrace) {
    addError(e, stackTrace);

    emit(
      state.copyWith(
        submissionStatus: SignUpSubmissionStatus.error,
        errorMessage: _describe(e),
      ),
    );
  }

  /// Renders an error from the identity service as text worth showing.
  String _describe(Object e) {
    final inner = e is SignUpWithPasswordFailure ? e.error : e;
    if (inner is EntraAuthApiException) {
      return EntraAuthenticationClient.friendlyMessage(inner);
    }
    return inner.toString();
  }

  /// Reports a locally-detected problem; the screen renders [cause] in the
  /// current language.
  void _fail(SignUpError cause) => emit(
    state.copyWith(
      submissionStatus: SignUpSubmissionStatus.error,
      error: cause,
    ),
  );
}

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:form_fields/form_fields.dart';
import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:user_repository/user_repository.dart';

part 'login_state.dart';

/// {@template login_cubit}
/// Cubit for login state management. It is used to change login state from
/// initial to in progress, success or error. It also validates email and
/// password fields.
/// {@endtemplate}
class LoginCubit extends Cubit<LoginState> {
  /// {@macro login_cubit}
  LoginCubit({required UserRepository userRepository})
    : _userRepository = userRepository,
      super(const LoginState.initial());

  final UserRepository _userRepository;

  /// Changes password visibility, making it visible or not.
  void changePasswordVisibility() =>
      emit(state.copyWith(showPassword: !state.showPassword));

  /// Emits initial state of login screen.
  void resetState() => emit(const LoginState.initial());

  /// Username value was changed, triggering new changes in state.
  void onUsernameChanged(String newValue) {
    final previousScreenState = state;
    final previousUsernameState = previousScreenState.username;
    final shouldValidate = previousUsernameState.invalid;
    final newUsernameState = shouldValidate
        ? Username.dirty(newValue)
        : Username.pure(newValue);

    final newScreenState = state.copyWith(username: newUsernameState);

    emit(newScreenState);
  }

  /// Username field was unfocused; validate it so the error shows after blur.
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

  /// Password value was changed, triggering new changes in state.
  /// Checking whether or not value is valid in [Password] and emmiting new
  /// [Password] validation state.
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

  /// Makes whole login state initial, as [Email] and [Password] becomes invalid
  /// and [LogInSubmissionStatus] becomes idle. Solely used if during login
  /// user switched on sign up, therefore login state does not persists and
  /// becomes initial again.
  void idle() {
    const initialState = LoginState.initial();
    emit(initialState);
  }

  Future<void> loginWithGoogle() async {
    emit(state.copyWith(status: LogInSubmissionStatus.googleAuthInProgress));
    try {
      await _userRepository.logInWithGoogle();
      emit(state.copyWith(status: LogInSubmissionStatus.success));
    } on LogInWithGoogleCanceled {
      emit(state.copyWith(status: LogInSubmissionStatus.idle));
    } catch (error, stackTrace) {
      _errorFormatter(error, stackTrace);
    }
  }

  Future<void> loginWithGithub() async {
    emit(state.copyWith(status: LogInSubmissionStatus.githubAuthInProgress));
    try {
      await _userRepository.logInWithGithub();
      emit(state.copyWith(status: LogInSubmissionStatus.success));
    } on LogInWithGithubCanceled {
      emit(state.copyWith(status: LogInSubmissionStatus.idle));
    } catch (error, stackTrace) {
      _errorFormatter(error, stackTrace);
    }
  }

  Future<void> onSubmit() async {
    final username = Username.dirty(state.username.value.trim());
    final password = Password.dirty(state.password.value);
    final isFormValid = FormzValid([username, password]).isFormValid;

    final newState = state.copyWith(
      username: username,
      password: password,
      status: isFormValid ? LogInSubmissionStatus.loading : null,
    );

    emit(newState);

    if (!isFormValid) return;

    try {
      // The auth client resolves the handle to the account's email.
      // Time-boxed so an unreachable server (PostgREST/Entra) surfaces a clear
      // error instead of spinning on "loading" forever.
      await _userRepository
          .logInWithPassword(
            email: username.value,
            password: password.value,
          )
          .timeout(const Duration(seconds: 20));
      final newState = state.copyWith(status: LogInSubmissionStatus.success);
      emit(newState);
    } on TimeoutException {
      // The network-error copy is localized in login_form.dart from the status.
      emit(state.copyWith(status: LogInSubmissionStatus.networkError));
    } catch (e, stackTrace) {
      _errorFormatter(e, stackTrace);
    }
  }

  /// Formats error, that occurred during login process.
  void _errorFormatter(Object e, StackTrace stackTrace) {
    addError(e, stackTrace);
    final status = switch (e) {
      LogInWithPasswordFailure() => LogInSubmissionStatus.error,
      LogInWithGoogleFailure() => LogInSubmissionStatus.googleLogInFailure,
      _ => LogInSubmissionStatus.idle,
    };

    final newState = state.copyWith(status: status, message: e.toString());
    emit(newState);
  }
}

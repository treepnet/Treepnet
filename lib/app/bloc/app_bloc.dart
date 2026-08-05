import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:treepnet/app/view/view.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:user_repository/user_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc({
    required User user,
    required UserRepository userRepository,
  }) : _userRepository = userRepository,
       super(
         user.isAnonymous
             ? const AppState.unauthenticated()
             : AppState.authenticated(user),
       ) {
    on<AppLogoutRequested>(_onAppLogoutRequested);
    on<AppUserChanged>(_onUserChanged);

    _userSubscription = userRepository.user.listen(
      _userChanged,
      onError: addError,
    );
  }

  final UserRepository _userRepository;

  StreamSubscription<User>? _userSubscription;

  void _userChanged(User user) => add(AppUserChanged(user));

  void _onUserChanged(AppUserChanged event, Emitter<AppState> emit) {
    final user = event.user;
    // Push tokens are gone with Firebase: on Android a notification can only
    // reach a closed app through Google's FCM, and nothing was sending them
    // anyway. In-app notifications still arrive — they come from the database.
    void authenticate() => emit(AppState.authenticated(user));

    switch (state.status) {
      case AppStatus.onboardingRequired:
      case AppStatus.authenticated:
      case AppStatus.unauthenticated:
        if (user.isAnonymous) {
          emit(const AppState.unauthenticated());
        } else {
          authenticate();
        }
        return;
    }
  }

  Future<void> _onAppLogoutRequested(
    AppLogoutRequested event,
    Emitter<AppState> emit,
  ) async {
    try {
      // Clear the push token first, while the user id is still valid, so this
      // signed-out device stops receiving notifications.
      await PushNotifications.disableForUser(_userRepository);
      await _userRepository.logOut();
      openSnackbar(
        SnackbarMessage.success(title: l10nGlobal.loggedOutSuccessfullyText),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      openSnackbar(
        SnackbarMessage.error(
          title: l10nGlobal.logOutFailedText,
          description: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }
}

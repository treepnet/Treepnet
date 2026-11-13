import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/chat/backend/chat_cache.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:shared/shared.dart' show logE;
import 'package:user_repository/user_repository.dart';

/// Ends the signed-in user's presence on this phone: their chat and app
/// pushes stop, their chat connection closes, and the chat plugin's cached
/// state is wiped — so nothing of theirs reaches the next account signed in
/// here. Call while their session is still valid: on sign-out, and on
/// account deletion (which used to skip it all).
///
/// Never throws, and takes a few seconds at most. The server calls (they
/// need the session) run side by side, given [_networkLimit] in all: they
/// used to run one after another with up to 30 s each, or no limit, so on a
/// slow connection signing out sat for a minute with nothing on screen. Past
/// the limit they go on in the background, or the token stays until the
/// next sign-in (the phone's own push token is deleted anyway, so nothing
/// arrives). Each local step is guarded on its own: one failing (e.g. the
/// chat's secure storage on a phone restored from a backup) used to stop
/// the sign-out itself.
Future<void> tearDownUserSession(UserRepository userRepository) async {
  // Pushes first, while the user id still works for the requests.
  await Future.wait([
    _safely('chat push token', ChatSession.instance.unregisterPushToken),
    _safely(
      'push token',
      () => PushNotifications.disableForUser(userRepository),
    ),
  ]).timeout(_networkLimit, onTimeout: () => const []);
  // Their notifications leave the tray: the next account could tap them.
  await _safely('notifications', PushNotifications.clearDelivered);
  // stop() closes the app-side socket; wipeSession() clears the plugin's
  // runtime identity and secure storage, so the previous user's messages
  // can't cross into the next user's threads.
  await _safely('chat stop', ChatSession.instance.stop);
  await _safely('chat wipe', MessengerChat.wipeSession);
  // The chat saved on the phone for offline use goes too, and what the
  // server's lists said about posts (counts, the user's likes).
  await _safely('chat cache', ChatCache.instance.clear);
  try {
    userRepository.forgetServerSnapshots();
  } catch (error, stackTrace) {
    logE(
      'Sign-out: forgetting snapshots failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

const _networkLimit = Duration(seconds: 5);

/// Runs one step, at most [_stepLimit], logging instead of throwing.
Future<void> _safely(String what, Future<void> Function() step) async {
  try {
    await step().timeout(_stepLimit);
  } catch (error, stackTrace) {
    logE('Sign-out: $what failed', error: error, stackTrace: stackTrace);
  }
}

const _stepLimit = Duration(seconds: 5);

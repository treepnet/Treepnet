import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/chat/backend/chat_cache.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:user_repository/user_repository.dart';

/// Ends the signed-in user's presence on this phone: their chat and app
/// pushes stop, their chat connection closes, and the chat plugin's cached
/// state is wiped — so nothing of theirs reaches the next account signed in
/// here. Call while their session is still valid: on sign-out, and on
/// account deletion (which used to skip it all).
Future<void> tearDownUserSession(UserRepository userRepository) async {
  // Pushes first, while the user id still works for the requests.
  await ChatSession.instance.unregisterPushToken();
  await PushNotifications.disableForUser(userRepository);
  // stop() closes the app-side socket; wipeSession() clears the plugin's
  // runtime identity and secure storage, so the previous user's messages
  // can't cross into the next user's threads.
  await ChatSession.instance.stop();
  await MessengerChat.wipeSession();
  // The chat saved on the phone for offline use goes too, and what the
  // server's lists said about posts (counts, the user's likes).
  await ChatCache.instance.clear();
  userRepository.forgetServerSnapshots();
}

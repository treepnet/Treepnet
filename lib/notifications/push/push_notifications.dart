import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:user_repository/user_repository.dart';

/// Handles a push that arrives while the app is in the background or fully
/// terminated. FCM *notification* messages are drawn by the OS itself, so there
/// is nothing to render here — but a background handler must still be
/// registered for Firebase Messaging to deliver in that state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty: notification payloads are shown by Android directly.
}

/// Thin wrapper around Firebase Cloud Messaging + local notifications.
///
/// Push was removed during the Supabase→Azure migration; this reintroduces it
/// as an FCM-transport-only integration (no other Firebase service is used).
/// See `PUSH_NOTIFICATIONS_PLAN.md`.
class PushNotifications {
  PushNotifications._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Must match the channel id in the FCM manifest meta-data so background and
  /// foreground notifications share one channel.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'treepnet_default_channel',
    'Notifications',
    description: 'Likes, comments, follows and messages',
    importance: Importance.high,
  );

  static bool _initialised = false;

  /// One-time setup: init Firebase, the local-notifications plugin and the
  /// Android channel, register the background handler and the foreground
  /// listener. Called from `bootstrap` before the app runs. Safe to call when
  /// no Firebase config exists for the flavor (staging/prod) — it just no-ops.
  static Future<void> initialize() async {
    if (_initialised) return;
    try {
      await Firebase.initializeApp();
    } catch (error) {
      // No google-services.json for this flavor (e.g. staging/prod not yet
      // registered) — skip push entirely rather than crash the app.
      if (kDebugMode) {
        // ignore: avoid_print
        print('PushNotifications: Firebase init skipped: $error');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: _onLocalTap,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Foreground messages are not auto-displayed by the OS, so draw them.
    // FirebaseMessaging.onMessage.listen(_showForeground);

    _initialised = true;
  }

  /// Requests the runtime notification permission (Android 13+ / iOS) and saves
  /// the device token to `profiles.push_token`. Call once the user is signed in
  /// so the prompt appears in-context, never on app launch.
  static Future<void> registerForUser(UserRepository userRepository) async {
    if (!_initialised) return;
    final messaging = FirebaseMessaging.instance;

    // Native, in-context runtime permission prompt.
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(userRepository, token);
    }

    // A token can rotate; keep the stored value fresh.
    messaging.onTokenRefresh.listen((t) => _saveToken(userRepository, t));
  }

  /// Clears the stored token so a signed-out device stops receiving pushes.
  /// Call *before* `logOut()` while the user id is still valid.
  static Future<void> disableForUser(UserRepository userRepository) async {
    try {
      await userRepository.updateUser(pushToken: '');
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best-effort; logout must not fail because of this.
    }
  }

  static Future<void> _saveToken(
    UserRepository userRepository,
    String token,
  ) async {
    try {
      await userRepository.updateUser(pushToken: token);
    } catch (_) {}
  }

  // static void _showForeground(RemoteMessage message) {
  //   final notification = message.notification;
  //   if (notification == null) return;
  //   _local.show(
  //     notification.hashCode,
  //     notification.title,
  //     notification.body,
  //     NotificationDetails(
  //       android: AndroidNotificationDetails(
  //         _channel.id,
  //         _channel.name,
  //         channelDescription: _channel.description,
  //         icon: 'ic_stat_notification',
  //         importance: Importance.high,
  //         priority: Priority.high,
  //       ),
  //     ),
  //     payload: jsonEncode(message.data),
  //   );
  // }

  static void _onLocalTap(NotificationResponse response) {
    // Deep-link routing from a tapped notification is wired in a later phase;
    // for now tapping simply opens the app.
  }
}

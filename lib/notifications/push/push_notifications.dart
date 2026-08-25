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

  /// The local-notifications plugin (OS display path) is ready. Does NOT need
  /// Firebase, so the OS can show notifications — including `simctl push` on
  /// the simulator and any local notification — on every flavor.
  static bool _localReady = false;

  /// Firebase Cloud Messaging (the remote-push transport) is available. Only
  /// true on a flavor that has a Firebase config (GoogleService-Info.plist /
  /// google-services.json). Real remote push needs this AND a real device.
  static bool _fcmReady = false;

  /// One-time setup. Two independent halves:
  ///  1. Local notifications + Android channel — no Firebase needed, so the OS
  ///     display path works on any flavor/device (and on the simulator).
  ///  2. FCM transport — only when a Firebase config exists; no-ops otherwise.
  /// Called from `bootstrap`; never throws to the caller.
  static Future<void> initialize() async {
    // 1) Local notifications (OS display path) — Firebase-independent.
    if (!_localReady) {
      const androidInit = AndroidInitializationSettings('ic_stat_notification');
      // Don't request iOS permission here — the prompt must appear in-context
      // (see `registerForUser`), never on app launch.
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
      _localReady = true;
    }

    // 2) FCM transport — remote push. No-ops without a Firebase config.
    if (!_fcmReady) {
      try {
        // Bounded so a hung Firebase init can never keep this future pending.
        await Firebase.initializeApp().timeout(const Duration(seconds: 10));
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
        _fcmReady = true;
      } catch (error) {
        // No Firebase config for this flavor, or init timed out. Local
        // notifications still work; there's just no remote-push transport.
        if (kDebugMode) {
          // ignore: avoid_print
          print('PushNotifications: FCM disabled (no Firebase config): $error');
        }
      }
    }
  }

  /// Requests the runtime notification permission (Android 13+ / iOS) and saves
  /// the device token to `profiles.push_token`. Call once the user is signed in
  /// so the prompt appears in-context, never on app launch.
  static Future<void> registerForUser(UserRepository userRepository) async {
    // In-context OS permission prompt. Uses the local-notifications plugin so
    // it works even without FCM — the OS can then display notifications
    // (incl. `simctl push` on the simulator) on any build.
    await _requestOsPermission();

    // Remote-push token — only when a Firebase config exists for this flavor.
    if (!_fcmReady) return;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _saveToken(userRepository, token);
    }

    // A token can rotate; keep the stored value fresh.
    messaging.onTokenRefresh.listen((t) => _saveToken(userRepository, t));
  }

  /// Requests the runtime notification permission via the local-notifications
  /// plugin (iOS + Android 13+). Independent of Firebase.
  static Future<void> _requestOsPermission() async {
    await _local
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Clears the stored token so a signed-out device stops receiving pushes.
  /// Call *before* `logOut()` while the user id is still valid.
  static Future<void> disableForUser(UserRepository userRepository) async {
    try {
      await userRepository.updateUser(pushToken: '');
      if (_fcmReady) await FirebaseMessaging.instance.deleteToken();
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

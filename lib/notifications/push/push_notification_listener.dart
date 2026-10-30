import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/notifications/push/push_navigation.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:user_repository/user_repository.dart';

/// Registers this device for push once the user is authenticated: it requests
/// the notification permission in-context and saves the FCM token to the
/// profile. Then it opens what a tapped notification is about (also the one
/// the app was launched from), and keeps the app language on the profile and
/// the chat backend so pushes come in it. Renders nothing.
///
/// Handles both cases: a fresh sign-in (the `unauthenticated → authenticated`
/// transition) *and* a cold start where the session is already restored (so no
/// transition ever fires) — the latter is covered by the initState check.
class PushNotificationListener extends StatefulWidget {
  const PushNotificationListener({super.key});

  @override
  State<PushNotificationListener> createState() =>
      _PushNotificationListenerState();
}

class _PushNotificationListenerState extends State<PushNotificationListener> {
  bool _registered = false;
  StreamSubscription<Map<String, String>>? _taps;

  /// The language last written to the profile this run.
  String? _syncedLang;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AppBloc>().state.status == AppStatus.authenticated) {
        _register();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also runs when the user switches the app language.
    if (_registered) _syncLanguage();
  }

  void _register() {
    if (_registered || !mounted) return;
    _registered = true;
    PushNotifications.registerForUser(context.read<UserRepository>());
    _syncLanguage();
    _taps ??= PushNotifications.taps.listen(_open);
    unawaited(
      PushNotifications.takeLaunchNotification().then((data) {
        if (data != null) _open(data);
      }),
    );
  }

  /// After a frame, so a cold start's first screen is in place underneath.
  void _open(Map<String, String> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(openFromNotification(data));
    });
  }

  void _syncLanguage() {
    final lang = Localizations.localeOf(context).languageCode == 'ru'
        ? 'ru'
        : 'en';
    ChatSession.instance.setLanguage(lang);
    if (lang == _syncedLang) return;
    _syncedLang = lang;
    unawaited(
      context.read<UserRepository>().updateUser(lang: lang).catchError((_) {}),
    );
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          previous.status != AppStatus.authenticated &&
          current.status == AppStatus.authenticated,
      listener: (context, _) => _register(),
      child: const SizedBox.shrink(),
    );
  }
}

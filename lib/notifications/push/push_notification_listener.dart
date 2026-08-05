import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';
import 'package:user_repository/user_repository.dart';

/// Registers this device for push once the user is authenticated: it requests
/// the notification permission in-context and saves the FCM token to the
/// profile. Renders nothing.
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

  void _register() {
    if (_registered || !mounted) return;
    _registered = true;
    PushNotifications.registerForUser(context.read<UserRepository>());
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

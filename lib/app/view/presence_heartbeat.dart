import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:user_repository/user_repository.dart';

/// Invisible widget that tells the server the signed-in user is here, once a
/// minute while the app is in front (admin "online now", sessions, last
/// seen). Stops when the app is backgrounded. Chat's online dot comes from
/// the chat socket, not this.
class PresenceHeartbeat extends StatefulWidget {
  const PresenceHeartbeat({super.key});

  @override
  State<PresenceHeartbeat> createState() => _PresenceHeartbeatState();
}

class _PresenceHeartbeatState extends State<PresenceHeartbeat>
    with WidgetsBindingObserver {
  Timer? _timer;
  // A minute: the admin's "online now" looks 2 minutes back and a session
  // runs on across gaps of up to 5.
  static const _interval = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    _beat();
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _beat());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _beat() {
    if (!mounted) return;
    final user = context.read<AppBloc>().state.user;
    if (user.isAnonymous || user.id.isEmpty) return;
    unawaited(context.read<UserRepository>().touchPresence());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

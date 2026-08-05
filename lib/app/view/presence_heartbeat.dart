import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:user_repository/user_repository.dart';

/// Invisible widget that keeps the signed-in user's `last_seen_at` fresh while
/// the app is foregrounded, so other people see an accurate online / last-seen
/// state in the chat header. Stops beating when the app is backgrounded.
class PresenceHeartbeat extends StatefulWidget {
  const PresenceHeartbeat({super.key});

  @override
  State<PresenceHeartbeat> createState() => _PresenceHeartbeatState();
}

class _PresenceHeartbeatState extends State<PresenceHeartbeat>
    with WidgetsBindingObserver {
  Timer? _timer;
  static const _interval = Duration(seconds: 45);

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
    unawaited(context.read<UserRepository>().updatePresence(userId: user.id));
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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/device_report.dart';
import 'package:user_repository/user_repository.dart';

/// Invisible widget that tells the server the signed-in user is here, once a
/// minute while the app is in front (admin "online now", sessions, last
/// seen). Stops when the app is backgrounded. Chat's online dot comes from
/// the chat socket, not this. It also tells the server which phone and app
/// version this is, once a day at most, signed in or not yet
/// ([DeviceReporter]: the admin's Devices page).
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

  final _devices = DeviceReporter();

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
    final signedIn = !user.isAnonymous && user.id.isNotEmpty;
    final repository = context.read<UserRepository>();
    if (signedIn) unawaited(repository.touchPresence());
    // Before sign-up too: the admin counts installs that never made an
    // account.
    unawaited(
      _devices.maybeReport(
        userId: signedIn ? user.id : '',
        send: (deviceId, info) => repository.reportDevice(
          deviceId: deviceId,
          platform: info.platform,
          appVersion: info.appVersion,
          build: info.build,
          osVersion: info.osVersion,
          model: info.model,
        ),
      ),
    );
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

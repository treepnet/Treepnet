import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Keeps [userId]'s profile syncing while [child] is on screen — for pages
/// that show someone's things without their profile page underneath (a place
/// on their map opened from a link). See `UserRepository.profileScope`.
class ProfileSyncScope extends StatefulWidget {
  const ProfileSyncScope({
    required this.userId,
    required this.child,
    super.key,
  });

  final String userId;
  final Widget child;

  @override
  State<ProfileSyncScope> createState() => _ProfileSyncScopeState();
}

class _ProfileSyncScopeState extends State<ProfileSyncScope> {
  late SyncScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = context.read<UserRepository>().profileScope(widget.userId);
  }

  @override
  void didUpdateWidget(ProfileSyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    _scope.close();
    _scope = context.read<UserRepository>().profileScope(widget.userId);
  }

  @override
  void dispose() {
    _scope.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

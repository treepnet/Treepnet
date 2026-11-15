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
    this.chatHeader = false,
    super.key,
  });

  final String userId;
  final Widget child;

  /// Only what a chat thread's header shows (card and stories), not the
  /// whole profile.
  final bool chatHeader;

  @override
  State<ProfileSyncScope> createState() => _ProfileSyncScopeState();
}

class _ProfileSyncScopeState extends State<ProfileSyncScope> {
  late SyncScope _scope;

  @override
  void initState() {
    super.initState();
    _scope = _open();
  }

  SyncScope _open() {
    final users = context.read<UserRepository>();
    return widget.chatHeader
        ? users.chatPeerScope(widget.userId)
        : users.profileScope(widget.userId);
  }

  @override
  void didUpdateWidget(ProfileSyncScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId &&
        oldWidget.chatHeader == widget.chatHeader) {
      return;
    }
    _scope.close();
    _scope = _open();
  }

  @override
  void dispose() {
    _scope.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

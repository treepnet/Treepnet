import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:user_repository/user_repository.dart';

/// Where the signed-in user stands with someone.
enum FollowRelation {
  /// Not following.
  none,

  /// Asked to follow a private account; not accepted yet.
  requested,

  /// Following.
  following,
}

/// Builds a follow button (or anything else) from the live relation to
/// [userId] — including a request still waiting on a private account.
///
/// Most buttons used to look only at accepted follows: after a request they
/// still said "Follow", and tapping it again (the database toggles) silently
/// withdrew the request. `relation` is null until the first answer.
class FollowStateBuilder extends StatefulWidget {
  const FollowStateBuilder({
    required this.userId,
    required this.builder,
    this.followerId,
    super.key,
  });

  final String userId;

  /// Whose relation; defaults to the signed-in user.
  final String? followerId;

  final Widget Function(BuildContext context, FollowRelation? relation)
  builder;

  @override
  State<FollowStateBuilder> createState() => _FollowStateBuilderState();
}

class _FollowStateBuilderState extends State<FollowStateBuilder> {
  /// Made once per user, not on every build.
  late Stream<String> _state;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(covariant FollowStateBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.followerId != widget.followerId) {
      _watch();
    }
  }

  void _watch() => _state = context.read<UserRepository>().followState(
    userId: widget.userId,
    followerId: widget.followerId,
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<String>(
    stream: _state,
    builder: (context, snapshot) => widget.builder(
      context,
      switch (snapshot.data) {
        null => null,
        'accepted' => FollowRelation.following,
        'pending' => FollowRelation.requested,
        _ => FollowRelation.none,
      },
    ),
  );
}

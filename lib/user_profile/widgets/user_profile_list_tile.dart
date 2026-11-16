import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:user_repository/user_repository.dart';

class UserProfileListTile extends StatefulWidget {
  const UserProfileListTile({
    required this.user,
    required this.follower,
    super.key,
  });

  final User user;
  final bool follower;

  @override
  State<UserProfileListTile> createState() => _UserProfileListTileState();
}

class _UserProfileListTileState extends State<UserProfileListTile> {
  late Future<bool> _isFollowed;

  @override
  void initState() {
    super.initState();
    _checkFollowed();
  }

  /// Whether the viewer follows this person (the Follow back button), asked
  /// again if the row is handed someone else.
  void _checkFollowed() {
    if (widget.follower) {
      _isFollowed = context.read<UserRepository>().isFollowed(
        userId: widget.user.id,
      );
    }
  }

  @override
  void didUpdateWidget(UserProfileListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.follower != widget.follower) {
      _checkFollowed();
    }
  }

  void _removeFollower(BuildContext context) {
    context.confirmAction(
      title: context.l10n.removeFollowerText,
      content: context.l10n.removeFollowerConfirmationText,
      yesText: context.l10n.removeText,
      noText: context.l10n.cancelText,
      fn: () => context.read<UserProfileBloc>().add(
        UserProfileRemoveFollowerRequested(userId: widget.user.id),
      ),
    );
  }

  /// What the person's follow button does, by what it shows: Follow follows,
  /// Requested withdraws the request, Following asks first (it unfollowed on
  /// one tap here, while the profile page asked).
  void _onFollowButton(BuildContext context, FollowRelation relation) =>
      onFollowButton(context, user: widget.user, relation: relation);

  @override
  Widget build(BuildContext context) {
    final profile = context.select((UserProfileBloc bloc) => bloc.state.user);
    final me = context.select((AppBloc bloc) => bloc.state.user);
    final isMe = widget.user.id == me.id;
    final isMine = me.id == profile.id;

    final avatar = UserStoriesAvatar(
      resizeHeight: 156,
      author: widget.user,
      withAdaptiveBorder: false,
      enableInactiveBorder: false,
      radius: 26,
    );

    // The user's own followers: the name takes what the two buttons leave,
    // both sized to their words. The Follow was a blue link squeezed in after
    // the name, and Remove took half the row.
    if (isMine && widget.follower) {
      return Tappable.faded(
        onTap: () => context.pushNamed(
          AppRoutes.userProfile.name,
          pathParameters: {'user_id': widget.user.id},
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            avatar,
            gapW8,
            Expanded(child: _NameAndFullName(user: widget.user)),
            gapW8,
            _FollowBackButton(wasFollowed: _isFollowed, user: widget.user),
            UserProfileButton(
              onTap: () => _removeFollower(context),
              label: context.l10n.removeText,
              padding: _compactPadding,
              textStyle: context.labelLarge?.copyWith(
                fontWeight: AppFontWeight.semiBold,
              ),
              fadeStrength: FadeStrength.md,
            ),
          ],
        ),
      );
    }

    return Tappable.faded(
      onTap: () => context.pushNamed(
        AppRoutes.userProfile.name,
        pathParameters: {'user_id': widget.user.id},
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          avatar,
          gapW8,
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: _NameAndFullName(user: widget.user)),
                gapH12,
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!(isMe && !isMine))
                        UserActionButton(
                          user: widget.user,
                          follower: widget.follower,
                          isMine: isMine,
                          isMe: isMe,
                          onTap: () => _removeFollower(context),
                          onFollowTap: (relation) =>
                              _onFollowButton(context, relation),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserActionButton extends StatelessWidget {
  const UserActionButton({
    required this.user,
    required this.isMe,
    required this.isMine,
    required this.follower,
    required this.onTap,
    required this.onFollowTap,
    super.key,
  });

  final User user;
  final bool isMe;
  final bool isMine;
  final bool follower;

  /// Remove (one of the user's own followers).
  final VoidCallback? onTap;

  /// The follow button, with what it showed.
  final ValueChanged<FollowRelation> onFollowTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xs,
    );
    final textStyle = context.bodyLarge?.copyWith(
      fontWeight: AppFontWeight.semiBold,
    );
    const fadeStrength = FadeStrength.md;

    late final Widget followerRemoveButton = UserProfileButton(
      onTap: onTap,
      label: context.l10n.removeText,
      padding: padding,
      textStyle: textStyle,
      fadeStrength: fadeStrength,
    );
    late final Widget followingButton = FollowStateBuilder(
      userId: user.id,
      builder: (context, relation) {
        if (relation == null) return const SizedBox.shrink();
        // Same pill as every other follow button: white to follow, #414141
        // once you do — or once you've asked (tapping withdraws the request).
        final grey = relation != FollowRelation.none;
        return UserProfileButton(
          onTap: () => onFollowTap(relation),
          label: switch (relation) {
            FollowRelation.following => l10n.followingUser,
            FollowRelation.requested => l10n.requestedText,
            FollowRelation.none => l10n.followUser,
          },
          padding: padding,
          fadeStrength: fadeStrength,
          color: grey ? const Color(0xFF414141) : AppColors.white,
          textStyle: context.labelLarge?.copyWith(
            color: grey ? AppColors.white : AppColors.black,
            fontWeight: AppFontWeight.semiBold,
          ),
        );
      },
    );

    final child = switch ((follower, isMine, isMe)) {
      (true, true, false) => followerRemoveButton,
      (true, false, false) => followingButton,
      (false, true, false) => followingButton,
      (false, false, false) => followingButton,
      _ => null,
    };

    return switch (child) {
      null => const SizedBox.shrink(),
      final Widget child => Flexible(flex: 9, child: child),
    };
  }
}

/// A row's buttons sized to their words: Remove and Follow side by side.
const _compactPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.md,
  vertical: AppSpacing.xs + AppSpacing.xxs,
);

/// The person's username over their name.
class _NameAndFullName extends StatelessWidget {
  const _NameAndFullName({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.displayUsername,
          style: context.bodyLarge?.copyWith(
            fontWeight: AppFontWeight.semiBold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          user.displayFullName,
          style: context.labelLarge?.copyWith(
            fontWeight: AppFontWeight.medium,
            color: AppColors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Follow back, on one of the user's own followers they don't follow: the
/// app's white pill with black words (it was a blue link). Once tapped it
/// shows what it became, grey, like every other follow button; nothing for
/// someone already followed when the list opened.
class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({required this.wasFollowed, required this.user});

  final Future<bool> wasFollowed;
  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<bool>(
      future: wasFollowed,
      builder: (context, snapshot) {
        final followed = snapshot.data;
        if (followed == null || followed) return const SizedBox.shrink();
        return FollowStateBuilder(
          userId: user.id,
          builder: (context, relation) {
            if (relation == null) return const SizedBox.shrink();
            final grey = relation != FollowRelation.none;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm - 2),
              child: UserProfileButton(
                onTap: () =>
                    onFollowButton(context, user: user, relation: relation),
                label: switch (relation) {
                  FollowRelation.following => l10n.followingUser,
                  FollowRelation.requested => l10n.requestedText,
                  FollowRelation.none => l10n.followUser,
                },
                padding: _compactPadding,
                fadeStrength: FadeStrength.md,
                color: grey ? const Color(0xFF414141) : AppColors.white,
                textStyle: context.labelLarge?.copyWith(
                  color: grey ? AppColors.white : AppColors.black,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A follow button's tap in a list, by what it showed: Follow follows,
/// Requested withdraws the request, Following asks first (see
/// [confirmUnfollow]).
void onFollowButton(
  BuildContext context, {
  required User user,
  required FollowRelation relation,
}) {
  final bloc = context.read<UserProfileBloc>();
  void send({required bool follow}) =>
      bloc.add(UserProfileFollowUserRequested(userId: user.id, follow: follow));
  switch (relation) {
    case FollowRelation.none:
      send(follow: true);
    case FollowRelation.requested:
      send(follow: false);
    case FollowRelation.following:
      unawaited(
        confirmUnfollow(
          context,
          username: user.displayUsername,
          isPrivate: user.isPrivate,
          onUnfollow: () => send(follow: false),
        ),
      );
  }
}

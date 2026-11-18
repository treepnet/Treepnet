import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/settings/view/referral_page.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared/shared.dart' hide Switch;
import 'package:user_repository/user_repository.dart';

class UserProfileHeader extends StatelessWidget {
  const UserProfileHeader({
    required this.userId,
    this.sponsoredPost,
    super.key,
  });

  final String userId;
  final PostSponsoredBlock? sponsoredPost;

  void _pushToUserStatistics(BuildContext context, {required int tabIndex}) =>
      context.pushNamed(
        AppRoutes.userStatistics.name,
        queryParameters: {'user_id': userId, 'tab': '$tabIndex'},
      );

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select((UserProfileBloc b) => b.isOwner);
    final blocked = context.select(
      (UserProfileBloc b) =>
          b.state.access == ProfileAccess.blockedByMe ||
          b.state.access == ProfileAccess.blockedByOwner,
    );
    final user$ = context.select((UserProfileBloc b) => b.state.user);
    final user = sponsoredPost == null
        ? user$
        : user$.isAnonymous
        ? sponsoredPost!.author.toUser
        : user$;
    final avatar = UserStoriesAvatar(
      resizeHeight: 252,
      author: user,
      onLongPress: (avatarUrl) =>
          avatarUrl == null ? null : context.showImagePreview(avatarUrl),
      onAvatarTap: (imageUrl) {
        if (imageUrl == null) return;
        if (!isOwner) context.showImagePreview(imageUrl);
        if (isOwner) {
          startStoryCreation(context, user);
        }
      },
      isLarge: true,
      tappableVariant: TappableVariant.scaled,
      showWhenSeen: true,
    );
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // With a name, bio or link: the avatar on the left and those
            // beside it (as Instagram). With none: the avatar centred alone.
            if (_ProfileBioBlock.hasContent(user))
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const Gap.h(AppSpacing.lg),
                  Expanded(
                    // A short one (a name) sits level with the avatar's
                    // middle; a longer one starts at its top.
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _avatarBox,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_ProfileBioBlock(user: user)],
                      ),
                    ),
                  ),
                ],
              )
            else
              Center(child: avatar),
            const Gap.v(AppSpacing.lg),
            UserProfileStatisticsCounts(
              onStatisticTap: (tabIndex) =>
                  _pushToUserStatistics(context, tabIndex: tabIndex),
            ),
            // Under the counts, the whole width: Invite friend on your own
            // profile; Follow and Message side by side on someone else's.
            // Blocked either way: none (the server forbids both across a
            // block).
            if (isOwner) ...[
              const Gap.v(AppSpacing.md),
              const _InviteFriendButton(),
            ] else if (!blocked) ...[
              const Gap.v(AppSpacing.md),
              const Row(
                children: [
                  Expanded(child: UserProfileFollowUserButton()),
                  Gap.h(AppSpacing.sm),
                  Expanded(child: _MessageUserButton()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The avatar's box on the profile: 2 × 42 (large) and its 12 of border.
  static const double _avatarBox = 96;
}

/// The referral entry point on your own profile: under the counts, the
/// whole width, as Follow / Message on someone else's (the same white button).
class _InviteFriendButton extends StatelessWidget {
  const _InviteFriendButton();

  @override
  Widget build(BuildContext context) {
    return UserProfileButton(
      color: AppColors.white,
      textStyle: context.labelLarge?.copyWith(color: AppColors.black),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(MaterialPageRoute(builder: (_) => const ReferralPage())),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_add_alt,
            size: AppSize.iconSizeSmall,
            color: AppColors.black,
          ),
          const Gap.h(AppSpacing.xs),
          Flexible(
            child: Text(
              context.l10n.inviteFriendText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.labelLarge?.copyWith(
                color: AppColors.black,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileStatisticsCounts extends StatelessWidget {
  const UserProfileStatisticsCounts({required this.onStatisticTap, super.key});

  final ValueSetter<int> onStatisticTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final postsCount = context.select(
      (UserProfileBloc bloc) => bloc.state.postsCount,
    );
    final followersCount = context.select(
      (UserProfileBloc bloc) => bloc.state.followersCount,
    );
    final followingsCount = context.select(
      (UserProfileBloc bloc) => bloc.state.followingsCount,
    );

    // Figma: three plain columns on the page background — no card, no border,
    // no dividers between them.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: UserProfileStatistic(
              name: l10n.postsCount(postsCount),
              value: postsCount,
            ),
          ),
          Expanded(
            child: UserProfileStatistic(
              name: l10n.followersText,
              value: followersCount,
              onTap: () => onStatisticTap.call(0),
            ),
          ),
          Expanded(
            child: UserProfileStatistic(
              name: context.l10n.subscribesText,
              value: followingsCount,
              onTap: () => onStatisticTap.call(1),
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileFollowUserButton extends StatelessWidget {
  const UserProfileFollowUserButton({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UserProfileBloc>();
    final user = context.select((UserProfileBloc bloc) => bloc.state.user);

    final l10n = context.l10n;

    // Tri-state: `none` → Follow, `pending` → Requested (private account,
    // awaiting approval), `accepted` → Following. Tapping Follow on a private
    // account sends a request; tapping Requested withdraws it; tapping
    // Following opens the unfollow modal.
    // One watch per profile, cancelled with the button (FollowStateBuilder).
    // It was bloc.followState() in build: a new watch on every build, never
    // cancelled (asBroadcastStream), one left running per profile visited.
    return FollowStateBuilder(
      userId: bloc.userId,
      builder: (context, relation) {
        final isFollowing = relation == FollowRelation.following;
        final isPending = relation == FollowRelation.requested;
        final grey = isFollowing || isPending;
        final label = isFollowing
            ? '${l10n.followingUser} ▼'
            : isPending
            ? l10n.requestedText
            : l10n.followUser;
        return UserProfileButton(
          label: label,
          // Figma: Follow is a solid white pill with black text; the
          // following/requested states are a grey pill with white text.
          color: grey ? AppColors.inputSpace : AppColors.white,
          textStyle: context.labelLarge?.copyWith(
            color: grey ? AppColors.white : AppColors.black,
          ),
          // Each state says what it does: Following asks, then unfollows;
          // Requested withdraws the request; Follow follows (or asks, for a
          // private account) and never undoes anything.
          onTap: isFollowing
              ? () => confirmUnfollow(
                  context,
                  username: user.displayUsername,
                  isPrivate: user.isPrivate,
                  onUnfollow: () => bloc.add(
                    const UserProfileFollowUserRequested(follow: false),
                  ),
                )
              : () => bloc.add(
                  UserProfileFollowUserRequested(follow: !isPending),
                ),
        );
      },
    );
  }
}

/// Gray "Message" button shown next to a non-owner's bio (Figma).
///
/// Opens (or creates) a 1:1 conversation with the profile's owner and pushes
/// the chat thread.
class _MessageUserButton extends StatelessWidget {
  const _MessageUserButton();

  Future<void> _openChat(BuildContext context) async {
    final participant = context.read<UserProfileBloc>().state.user;
    await openChat(
      context,
      peerUuid: participant.id,
      peerName: participant.displayUsername,
      peerAvatarUrl: participant.hasAvatar ? participant.avatarUrl : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return UserProfileButton(
      label: context.l10n.messageText,
      // Figma: grey pill, white text.
      color: AppColors.inputSpace,
      textStyle: context.labelLarge?.copyWith(color: AppColors.white),
      onTap: () => _openChat(context),
    );
  }
}

/// Left-aligned bio block: `Name / About / link`, beside the avatar.
class _ProfileBioBlock extends StatelessWidget {
  const _ProfileBioBlock({required this.user});

  final User user;

  /// Whether [user] filled in a name, a bio or a link (else there is no
  /// block, and the avatar stands alone in the middle).
  static bool hasContent(User user) =>
      (user.fullName?.trim().isNotEmpty ?? false) ||
      (user.bio?.trim().isNotEmpty ?? false) ||
      (user.website?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    // Only what the user filled in. An empty name showed the username, and
    // an empty bio "@username", while the username is already at the top.
    final name = user.fullName?.trim() ?? '';
    final bio = user.bio?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The values speak for themselves — no "Name:" / "About:" labels.
        if (name.isNotEmpty)
          Text(
            name,
            style: context.bodyLarge?.copyWith(
              color: AppColors.white,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        if (name.isNotEmpty && bio.isNotEmpty) const Gap.v(AppSpacing.xxs),
        if (bio.isNotEmpty)
          Text(
            user.bio!,
            style: context.bodyMedium?.copyWith(color: AppColors.white),
          ),
        // The one link the profile has (Telegram, Instagram, a site...):
        // whatever the user filled in.
        if (user.website != null && user.website!.trim().isNotEmpty) ...[
          if (name.isNotEmpty || bio.isNotEmpty) const Gap.v(AppSpacing.xs),
          _LinkRow(
            icon: Icons.link,
            label: user.website!,
            url: _webUrl(user.website!),
          ),
        ],
      ],
    );
  }

  /// People type `example.com`; a URL needs the scheme.
  static String _webUrl(String value) {
    final v = value.trim();
    if (v.startsWith('http://') || v.startsWith('https://')) return v;
    return 'https://$v';
  }
}

/// One tappable profile link.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});

  final IconData icon;
  final String label;
  final String url;

  Future<void> _open() async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Silent on failure: a mistyped handle is not worth an error dialog.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: _open,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colorScheme.onSurface),
          const Gap.h(AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.blue,
                fontSize: 14,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

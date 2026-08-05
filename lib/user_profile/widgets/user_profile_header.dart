import 'package:app_ui/app_ui.dart';
import 'package:chats_repository/chats_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chats/chat/chat.dart';
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
        extra: tabIndex,
        queryParameters: {'user_id': userId},
      );

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select((UserProfileBloc b) => b.isOwner);
    final user$ = context.select((UserProfileBloc b) => b.state.user);
    final user = sponsoredPost == null
        ? user$
        : user$.isAnonymous
        ? sponsoredPost!.author.toUser
        : user$;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            Center(
              child: UserStoriesAvatar(
                resizeHeight: 252,
                author: user,
                onLongPress: (avatarUrl) => avatarUrl == null
                    ? null
                    : context.showImagePreview(avatarUrl),
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
              ),
            ),
            const Gap.v(AppSpacing.lg),
            UserProfileStatisticsCounts(
              onStatisticTap: (tabIndex) =>
                  _pushToUserStatistics(context, tabIndex: tabIndex),
            ),
            const Gap.v(AppSpacing.lg),
            if (isOwner)
              // Editing lives behind the pencil in the app bar, so the profile
              // itself just shows the bio block (with its Invite friend
              // button — only ever on your own profile).
              _ProfileBioBlock(user: user, isOwner: true)
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ProfileBioBlock(user: user)),
                  const Gap.h(AppSpacing.md),
                  const SizedBox(
                    width: 140,
                    child: Column(
                      children: [
                        UserProfileFollowUserButton(),
                        SizedBox(height: 8),
                        _MessageUserButton(),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The referral entry point, shown opposite the name/bio on your own profile.
class _InviteFriendButton extends StatelessWidget {
  const _InviteFriendButton();

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(MaterialPageRoute(builder: (_) => const ReferralPage())),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt,
              size: AppSize.iconSizeSmall,
              color: AppColors.black,
            ),
            const Gap.h(AppSpacing.xs),
            Text(
              context.l10n.inviteFriendText,
              style: context.labelLarge?.copyWith(
                color: AppColors.black,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ],
        ),
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

class EditProfileButton extends StatelessWidget {
  const EditProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return UserProfileButton(
      label: context.l10n.editProfileText,
      onTap: () => context.pushNamed(AppRoutes.editProfile.name),
    );
  }
}

class ShareProfileButton extends StatelessWidget {
  const ShareProfileButton({super.key});

  Future<void> _share(BuildContext context) async {
    final user = context.read<UserProfileBloc>().state.user;
    final link = 'https://treepnet.com/${user.displayUsername}';
    final title = context.l10n.profileLinkCopiedText;
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    openSnackbar(SnackbarMessage.success(title: title), clearIfQueue: true);
  }

  @override
  Widget build(BuildContext context) {
    return UserProfileButton(
      label: context.l10n.shareProfileText,
      onTap: () => _share(context),
    );
  }
}

/// Opens the "Discover people" list (accounts you don't follow yet).
class ShowSuggestedPeopleButton extends StatelessWidget {
  const ShowSuggestedPeopleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return UserProfileButton(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const DiscoverPeoplePage()),
      ),
      child: const Icon(Icons.person_add_outlined, size: 20),
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
    return StreamBuilder<String>(
      stream: bloc.followState(),
      initialData: 'none',
      builder: (context, snapshot) {
        final state = snapshot.data ?? 'none';
        final isFollowing = state == 'accepted';
        final isPending = state == 'pending';
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
          onTap: isFollowing
              ? () async {
                  void callback(ModalOption option) =>
                      option.onTap.call(context);

                  final option = await context.showListOptionsModal(
                    title: user.username,
                    options: followerModalOptions(
                      unfollowLabel: context.l10n.cancelFollowingText,
                      onUnfollowTap: () =>
                          bloc.add(const UserProfileFollowUserRequested()),
                    ),
                  );
                  if (option == null) return;
                  callback.call(option);
                }
              // `none` follows (request or immediate); `pending` toggles the
              // request off — both go through the same event, which the DB
              // layer resolves by inserting or deleting the subscription row.
              : () => bloc.add(const UserProfileFollowUserRequested()),
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
    final currentUserId = context.read<AppBloc>().state.user.id;
    final participant = context.read<UserProfileBloc>().state.user;
    if (participant.isAnonymous || participant.id == currentUserId) return;

    final chatId = await context.read<ChatsRepository>().createChat(
      userId: currentUserId,
      participantId: participant.id,
    );
    if (!context.mounted) return;

    await context.pushNamed(
      AppRoutes.chat.name,
      pathParameters: {'chat_id': chatId},
      extra: ChatProps(
        chat: ChatInbox(id: chatId, participant: participant),
      ),
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

/// Left-aligned bio block: `Name / About / link`, matching the Figma design.
class _ProfileBioBlock extends StatelessWidget {
  const _ProfileBioBlock({required this.user, this.isOwner = false});

  final User user;

  /// Only your own profile gets the Invite friend button.
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final bio = (user.bio != null && user.bio!.trim().isNotEmpty)
        ? user.bio!
        : '@${user.displayUsername}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The values speak for themselves — no "Name:" / "About:" labels.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayFullName,
                    style: context.bodyLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
                  const Gap.v(AppSpacing.xxs),
                  Text(
                    bio,
                    style: context.bodyMedium?.copyWith(color: AppColors.white),
                  ),
                ],
              ),
            ),
            if (isOwner) ...[
              const Gap.h(AppSpacing.md),
              const _InviteFriendButton(),
            ],
          ],
        ),
        // Whatever the user actually filled in — the link row used to be
        // hardcoded to `t.me/<app username>`, so editing it changed nothing
        // here and looked like the edit had been lost.
        if (user.telegram != null && user.telegram!.trim().isNotEmpty) ...[
          const Gap.v(AppSpacing.xs),
          _LinkRow(
            icon: Icons.send,
            label: 't.me/${user.telegram}',
            url: 'https://t.me/${user.telegram}',
          ),
        ],
        if (user.instagram != null && user.instagram!.trim().isNotEmpty) ...[
          const Gap.v(AppSpacing.xs),
          _LinkRow(
            icon: Icons.camera_alt_outlined,
            label: 'instagram.com/${user.instagram}',
            url: 'https://instagram.com/${user.instagram}',
          ),
        ],
        if (user.website != null && user.website!.trim().isNotEmpty) ...[
          const Gap.v(AppSpacing.xs),
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

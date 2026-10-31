import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/widgets/follow_state_builder.dart';
import 'package:user_repository/user_repository.dart';

/// {@template notifications_page}
/// The activity feed, opened from the bell in the feed app bar: real likes,
/// comments and new followers on the current user, newest first.
/// {@endtemplate}
class NotificationsPage extends StatelessWidget {
  /// {@macro notifications_page}
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AppBloc>().state.user.id;
    final repo = context.read<UserRepository>();
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.notificationsText,
            style: context.titleMedium?.copyWith(
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        body: StreamBuilder<List<NotificationItem>>(
          stream: repo.notificationsOf(userId: userId),
          builder: (context, snapshot) {
            final items = snapshot.data;
            if (items == null) {
              return const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (items.isEmpty) return const _EmptyNotifications();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 70,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              itemBuilder: (context, i) => _NotificationTile(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  void _onTap(BuildContext context) {
    if (item.actorId.isEmpty) return;
    // A like or comment opens the post it's about; a message opens the
    // conversation; a follow opens the person's profile. (Likes and comments
    // used to open the liker's profile.)
    final postId = item.postId;
    if ((item.type == NotificationType.like ||
            item.type == NotificationType.comment) &&
        postId != null) {
      context.pushNamed(AppRoutes.post.name, pathParameters: {'id': postId});
      return;
    }
    if (item.type == NotificationType.message) {
      unawaited(
        openChat(
          context,
          peerUuid: item.actorId,
          peerName: item.actorUsername,
          peerAvatarUrl: item.actorAvatarUrl,
        ),
      );
      return;
    }
    context.pushNamed(
      AppRoutes.userProfile.name,
      pathParameters: {'user_id': item.actorId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = item.actorAvatarUrl;
    return ListTile(
      onTap: item.actorId.isEmpty ? null : () => _onTap(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        // Cached, and decoded at the avatar's size.
        backgroundImage: (avatar != null && avatar.isNotEmpty)
            ? ResizeImage(CachedNetworkImageProvider(avatar), width: 120)
            : null,
        child: (avatar == null || avatar.isEmpty)
            ? const Icon(Icons.person, color: Colors.white54)
            : null,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              item.actorUsername,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Gap.h(AppSpacing.xs),
          // Was a hardcoded tick on every row — it appeared beside people who
          // had never earned one. The live badge shows nothing when there is
          // nothing to show.
          TravelTierBadge(userId: item.actorId),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: _action(item)),
              TextSpan(
                text: ' ${_ago(context, item.createdAt)}',
                style: const TextStyle(color: Colors.white38),
              ),
            ],
          ),
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
      trailing: _trailing(context),
    );
  }

  Widget? _trailing(BuildContext context) {
    switch (item.type) {
      case NotificationType.follow:
        return _FollowBackButton(actorId: item.actorId);
      case NotificationType.followRequest:
        return _FollowRequestButtons(requesterId: item.actorId);
      case NotificationType.like:
      case NotificationType.comment:
        return item.postId == null ? null : _PostThumb(url: item.postThumbUrl);
      case NotificationType.message:
        return null;
    }
  }

  String _action(NotificationItem n) {
    final l10n = l10nGlobal;
    switch (n.type) {
      case NotificationType.like:
        return l10n.notifLikedText;
      case NotificationType.comment:
        final text = (n.content ?? '').trim();
        return text.isEmpty
            ? l10n.notifCommentedText
            : l10n.notifCommentedContentText(text);
      case NotificationType.follow:
        return l10n.notifFollowedText;
      case NotificationType.followRequest:
        return l10n.notifFollowRequestText;
      case NotificationType.message:
        final text = (n.content ?? '').trim();
        return text.isEmpty
            ? l10n.notifMessageText
            : l10n.notifMessageContentText(text);
    }
  }

  /// In the app's language ("5 min." / "5 мин."), like comments; the
  /// letters "5m / 3h / 2d" were English for everyone.
  static String _ago(BuildContext context, DateTime? time) {
    if (time == null) return '';
    if (DateTime.now().difference(time).inSeconds < 60) {
      return context.l10n.nowText;
    }
    return time.timeAgoShort(context);
  }
}

/// The white "Follow" / grey "Following" pill on a follow notification.
class _FollowBackButton extends StatelessWidget {
  const _FollowBackButton({required this.actorId});

  final String actorId;

  @override
  Widget build(BuildContext context) {
    if (actorId.isEmpty) return const SizedBox.shrink();
    final me = context.read<AppBloc>().state.user.id;
    final repo = context.read<UserRepository>();
    return FollowStateBuilder(
      userId: actorId,
      followerId: me,
      builder: (context, relation) {
        // Grey once following or once asked (tapping withdraws the request).
        final following = relation == FollowRelation.following ||
            relation == FollowRelation.requested;
        return Tappable.scaled(
          onTap: () => following
              ? repo.unfollow(unfollowId: actorId, unfollowerId: me)
              : repo.follow(followToId: actorId, followerId: me),
          child: Container(
            width: 110,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: following ? AppColors.inputSpace : AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              switch (relation) {
                FollowRelation.following => context.l10n.followingUser,
                FollowRelation.requested => context.l10n.requestedText,
                _ => context.l10n.followUser,
              },
              style: context.labelLarge?.copyWith(
                fontSize: 16,
                color: following ? AppColors.white : AppColors.black,
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Accept / Decline pills on a follow-REQUEST notification (private account).
/// Accepting turns the pending request into a follow — the row then reappears
/// as a normal "started following you" notice; declining removes it, so this
/// notification disappears. Both happen reactively via the notifications
/// stream, no manual refresh needed.
class _FollowRequestButtons extends StatelessWidget {
  const _FollowRequestButtons({required this.requesterId});

  final String requesterId;

  @override
  Widget build(BuildContext context) {
    if (requesterId.isEmpty) return const SizedBox.shrink();
    final repo = context.read<UserRepository>();
    // Two stacked pills must fit the notification tile's ~56px height, so keep
    // them compact (25 + 4 + 25 = 54) — otherwise the lower one overflows past
    // the tile bounds and stops receiving taps.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pill(
          context,
          label: context.l10n.acceptText,
          filled: true,
          onTap: () => repo.acceptFollowRequest(requesterId: requesterId),
        ),
        const SizedBox(height: 4),
        _pill(
          context,
          label: context.l10n.declineText,
          filled: false,
          onTap: () => repo.declineFollowRequest(requesterId: requesterId),
        ),
      ],
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return Tappable.scaled(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.white : AppColors.inputSpace,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: context.labelLarge?.copyWith(
            fontSize: 13,
            color: filled ? AppColors.black : AppColors.white,
            fontWeight: AppFontWeight.semiBold,
          ),
        ),
      ),
    );
  }
}

/// The small post thumbnail on a like / comment notification. Its address
/// comes with the notification; each row used to fetch its whole post — again
/// on every rebuild of the list — and decode the full photo uncached.
class _PostThumb extends StatelessWidget {
  const _PostThumb({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: url == null || url.isEmpty
          ? null
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 126,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white54,
                size: 46,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.noNotificationsText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.noNotificationsHintText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

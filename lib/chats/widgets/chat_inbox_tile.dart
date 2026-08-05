import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chats/chat/chat.dart';
import 'package:treepnet/chats/chats.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/shared.dart';

class ChatInboxTile extends StatelessWidget {
  const ChatInboxTile({required this.chat, super.key});

  final ChatInbox chat;

  @override
  Widget build(BuildContext context) {
    final participant = chat.participant;
    final user = context.select((AppBloc bloc) => bloc.state.user);
    // Design: a flat row — avatar, name, then the unread badge on the right,
    // with a hairline divider between rows (no glass card).
    return Column(
      children: [
        Tappable.faded(
          backgroundColor: AppColors.transparent,
          onTap: () => context.pushNamed(
            AppRoutes.chat.name,
            pathParameters: {'chat_id': chat.id},
            extra: ChatProps(chat: chat),
          ),
          onLongPress: () => context.confirmAction(
            title: context.l10n.deleteChatText,
            content: context.l10n.chatDeleteConfirmationText,
            yesText: context.l10n.deleteText,
            noText: context.l10n.cancelText,
            yesTextStyle: context.labelLarge?.copyWith(
              color: AppColors.red,
              fontWeight: AppFontWeight.semiBold,
            ),
            fn: () => context.read<ChatsBloc>().add(
              ChatsDeleteChatRequested(chatId: chat.id, userId: user.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + AppSpacing.xxs,
            ),
            child: Row(
              children: [
                UserStoriesAvatar(
                  resizeHeight: 156,
                  author: participant,
                  enableInactiveBorder: false,
                  withAdaptiveBorder: false,
                  radius: 22,
                  // Tapping the avatar opens the chat (not the profile). If the
                  // person has an active story, the avatar still opens the
                  // story — that behaviour lives inside UserStoriesAvatar.
                  onAvatarTap: (_) => context.pushNamed(
                    AppRoutes.chat.name,
                    pathParameters: {'chat_id': chat.id},
                    extra: ChatProps(chat: chat),
                  ),
                ),
                const Gap.h(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              // Only the username in the inbox — no full name.
                              participant.displayUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.bodyLarge?.copyWith(
                                fontWeight: AppFontWeight.semiBold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                          const Gap.h(AppSpacing.xs),
                          TravelTierBadge(userId: participant.id),
                        ],
                      ),
                      // Last-message preview under the name — the inbox row used
                      // to show only the name and time.
                      if ((chat.lastMessage ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            chat.lastMessage!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap.h(AppSpacing.sm),
                // Design: unread badge on top, the last message's time under it.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chat.unreadMessagesCount > 0)
                      _UnreadBadge(count: chat.unreadMessagesCount),
                    if (chat.lastMessageAt != null) ...[
                      if (chat.unreadMessagesCount > 0)
                        const Gap.v(AppSpacing.xxs),
                      Text(
                        _formatTime(chat.lastMessageAt!),
                        style: context.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        // Hairline like the Type tab: a small inset on both sides, not
        // aligned past the avatar and not edge-to-edge.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderOutline.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// `HH:mm` for today's messages, `dd.MM` for anything older — the inbox row
/// only has space for one short label.
String _formatTime(DateTime at) {
  // Show the stored wall-clock exactly as the message bubble does (which uses
  // .format() with no timezone conversion). Calling toLocal() here treated the
  // value as UTC and shifted it by the local offset (12:23 → 17:23).
  final now = DateTime.now();
  final isToday =
      at.year == now.year && at.month == now.month && at.day == now.day;
  String two(int v) => v.toString().padLeft(2, '0');
  return isToday
      ? '${two(at.hour)}:${two(at.minute)}'
      : '${two(at.day)}.${two(at.month)}';
}

/// The blue pill showing how many messages are waiting in a chat.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.sm + AppSpacing.xxs),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: context.bodySmall?.copyWith(
          color: AppColors.black,
          fontWeight: AppFontWeight.semiBold,
        ),
      ),
    );
  }
}

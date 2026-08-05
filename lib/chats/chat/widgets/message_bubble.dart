import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chats/chat/chat.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    this.onMessageTap,
    this.onEditTap,
    this.onReplyTap,
    this.onDeleteTap,
    this.onRepliedMessageTap,
    this.borderRadius,
    super.key,
  });

  final Message message;
  final ValueSetter<Message>? onReplyTap;
  final ValueSetter<Message>? onEditTap;
  final ValueSetter<Message>? onDeleteTap;
  final ValueSetter<String>? onRepliedMessageTap;
  final BorderRadiusGeometry Function({required bool isMine})? borderRadius;
  final OnMessageTap<MessageAction>? onMessageTap;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    final user = context.read<AppBloc>().state.user;
    final isMine = message.sender?.id == user.id;
    final messageAlignment = !isMine ? Alignment.topLeft : Alignment.topRight;

    final messageWidget = GestureDetector(
      onTapUp: (details) async {
        late final onDeleteTap = context.confirmAction(
          title: context.l10n.deleteMessageText,
          content: context.l10n.messageDeleteConfirmationText,
          yesText: context.l10n.deleteText,
          noText: context.l10n.cancelText,
          fn: () => this.onDeleteTap?.call(message),
        );
        final option = await onMessageTap?.call(
          details,
          message.id,
          isMine: isMine,
          hasSharedPost:
              message.sharedPost != null ||
              message.sharedPostId == null && message.sharedPost != null,
        );
        if (option == null) return;
        return switch (option) {
          MessageAction.delete => onDeleteTap,
          MessageAction.edit => onEditTap?.call(message),
          MessageAction.reply => onReplyTap?.call(message),
        };
      },
      child: FractionallySizedBox(
        alignment: messageAlignment,
        widthFactor: 0.85,
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: messageAlignment,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius:
                        borderRadius?.call(isMine: isMine) ??
                        const BorderRadius.all(Radius.circular(22)),
                    // Design bubbles are a flat fill with no outline.
                  ),
                  child: ClipPath(
                    clipper: ShapeBorderClipper(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            borderRadius?.call(isMine: isMine) ??
                            const BorderRadius.all(Radius.circular(22)),
                      ),
                    ),
                    child: RepaintBoundary(
                      child: MessageBubbleContent(
                        message: message,
                        onRepliedMessageTap: onRepliedMessageTap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Design: timestamp (and ticks for your own messages) below the
            // bubble rather than tucked inside it.
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.xxs,
              ),
              child: MessageStatuses(
                isEdited: message.isEdited,
                message: message,
              ),
            ),
          ],
        ),
      ),
    );

    if (isMine || isMine && message.isRead || !isMine && message.isRead) {
      return messageWidget;
    }

    return Viewable(
      itemKey: ValueKey(message.id),
      onSeen: () => context.read<ChatBloc>().add(ChatMessageSeen(message.id)),
      child: messageWidget,
    );
  }
}

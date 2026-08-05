import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/comments/comments.dart';
import 'package:treepnet/l10n/l10n.dart';

class CommentTextField extends StatefulWidget {
  const CommentTextField({
    required this.controller,
    required this.postId,
    super.key,
  });

  final String postId;
  final DraggableScrollableController controller;

  @override
  State<CommentTextField> createState() => _CommentTextFieldState();
}

class _CommentTextFieldState extends State<CommentTextField> {
  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc b) => b.state.user);
    final commentInputController = CommentsPage.of(
      context,
    ).commentInputController;

    return Padding(
      padding: EdgeInsets.only(bottom: context.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListenableBuilder(
            listenable: commentInputController,
            builder: (context, child) {
              return Offstage(
                offstage: !commentInputController.isReplying,
                child: ListTile(
                  // customReversedAdaptiveColor hands back the *light* value in
                  // dark mode, which painted this banner near-white over the
                  // comments. Same trap as the Comments and Share sheets.
                  tileColor: AppColors.background,
                  title: Text(
                    context.l10n.replyToText(
                      commentInputController.replyingUsername ?? context.l10n.unknownText,
                    ),
                    style: context.bodyMedium?.apply(color: AppColors.grey),
                  ),
                  trailing: Tappable.faded(
                    onTap: commentInputController.clear,
                    child: const Icon(Icons.cancel, color: AppColors.grey),
                  ),
                ),
              );
            },
          ),
          const Gap.v(AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: commentEmojies
                      .map(
                        (emoji) => Flexible(
                          child: FittedBox(
                            child: TextEmoji(
                              emoji: emoji,
                              onEmojiTap: commentInputController.onEmojiTap,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                // Figma: a single rounded input on `Input space` with a send
                // icon beside it — no avatar, no underline, no text button.
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            textController:
                                commentInputController.commentTextController,
                            focusNode:
                                commentInputController.commentFocusNode,
                            filled: true,
                            fillColor: AppColors.inputSpace,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            hintText: context.l10n.addCommentText,
                            textInputType: TextInputType.text,
                            textInputAction: TextInputAction.newline,
                            border: outlinedBorder(borderRadius: 26),
                          ),
                        ),
                        const Gap.h(AppSpacing.md),
                        ListenableBuilder(
                          listenable:
                              commentInputController.commentTextController,
                          builder: (context, _) {
                            final hasText = commentInputController
                                .commentTextController
                                .text
                                .trim()
                                .isNotEmpty;
                            return Tappable.scaled(
                              onTap: !hasText
                                  ? null
                                  : () {
                                      context.read<CommentsBloc>().add(
                                        CommentsCommentCreateRequested(
                                          userId: user.id,
                                          content: commentInputController
                                              .commentTextController
                                              .value
                                              .text,
                                          repliedToCommentId:
                                              commentInputController
                                                  .replyingCommentId,
                                        ),
                                      );
                                      commentInputController.clear();
                                    },
                              child: Icon(
                                Icons.send,
                                size: 26,
                                color: hasText
                                    ? AppColors.white
                                    : AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
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

class TextEmoji extends StatelessWidget {
  const TextEmoji({required this.emoji, required this.onEmojiTap, super.key});

  final String emoji;
  final ValueSetter<String> onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: () => onEmojiTap(emoji),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.xlg),
        child: Text(emoji, style: context.displayMedium),
      ),
    );
  }
}

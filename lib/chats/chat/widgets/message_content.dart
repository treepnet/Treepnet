import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chats/chat/bloc/chat_bloc.dart';
import 'package:treepnet/chats/chat/widgets/widgets.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/widgets/stories_props.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:intl/intl.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:shared/shared.dart';

class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    required this.message,
    this.onRepliedMessageTap,
    super.key,
  });

  final Message message;
  final ValueSetter<String>? onRepliedMessageTap;

  bool get hasNonUrlAttachments =>
      message.attachments.any((a) => a.type != AttachmentType.urlPreview.value);

  bool get hasUrlAttachments =>
      message.attachments.any((a) => a.type == AttachmentType.urlPreview.value);

  bool get hasAttachments => hasUrlAttachments || hasNonUrlAttachments;

  bool get hasRepliedMessage =>
      (message.repliedMessage != null &&
          message.repliedMessage != Message.empty) ||
      (message.replyMessageId != null &&
          (message.replyMessageId?.isNotEmpty ?? false));

  bool get displayBottomStatuses => hasAttachments;

  bool get isEdited =>
      message.createdAt.isAfter(message.updatedAt) &&
          !message.createdAt.isAtSameMomentAs(message.updatedAt) ||
      message.isEdited;

  bool get isSharedPostUnavailable =>
      message.sharedPostId == null && message.message.trim().isEmpty;

  bool get hasSharedPost =>
      message.sharedPost != null &&
      message.replyMessageId == null &&
      message.replyMessageAttachmentUrl == null;

  bool get isSharedPostReel => message.sharedPost?.isReel ?? false;

  bool get hasSharedStory =>
      message.sharedStory != null &&
      message.replyMessageId == null &&
      message.replyMessageAttachmentUrl == null;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);
    final isMine = message.sender?.id == user.id;
    final sharedPost = message.sharedPost;

    // A shared story is its own preview; check it before the post arms (an
    // empty shared-story message would otherwise read as "post unavailable").
    if (hasSharedStory) {
      return MessageBubbleBackground(
        colors: const [AppColors.inputSpace, AppColors.inputSpace],
        child: MessageSharedStory(story: message.sharedStory!),
      );
    }

    // The chat always renders on a dark background, so incoming bubbles use
    // light text on a subtle light fill regardless of the platform theme —
    // previously a "light" theme made incoming text black and the fill nearly
    // black, so replies were invisible on the dark chat.
    const effectiveTextColor = AppColors.white;

    // The design gives both sides the same flat grey bubble — no gradient for
    // outgoing, no translucent fill for incoming. Passing one colour twice
    // makes the gradient render as a solid fill.
    return MessageBubbleBackground(
      colors: const [AppColors.inputSpace, AppColors.inputSpace],
      child: switch ((
        isSharedPostUnavailable,
        hasSharedPost,
        isSharedPostReel,
      )) {
        (true, _, _) => MessageSharedPostUnavailable(
          message: message,
          isEdited: isEdited,
          effectiveTextColor: effectiveTextColor,
        ),
        (false, true, true) => MessageSharedReel(
          sharedPost: sharedPost!,
          effectiveTextColor: effectiveTextColor,
          isEdited: isEdited,
          message: message,
        ),
        (false, true, false) => MessageSharedPost(
          sharedPost: sharedPost!,
          effectiveTextColor: effectiveTextColor,
          isEdited: isEdited,
          message: message,
        ),
        (false, false, _) => MessageContentView(
          message: message,
          isMine: isMine,
          isEdited: isEdited,
          hasAttachments: hasAttachments,
          effectiveTextColor: effectiveTextColor,
          onRepliedMessageTap: onRepliedMessageTap,
          hasRepliedMessage: hasRepliedMessage,
          displayBottomStatuses: displayBottomStatuses,
        ),
      },
    );
  }
}

class MessageContentView extends StatelessWidget {
  const MessageContentView({
    required this.hasRepliedMessage,
    required this.message,
    required this.displayBottomStatuses,
    required this.isMine,
    required this.effectiveTextColor,
    required this.isEdited,
    required this.hasAttachments,
    this.onRepliedMessageTap,
    super.key,
  });

  final Message message;
  final Color effectiveTextColor;
  final ValueSetter<String>? onRepliedMessageTap;
  final bool isMine;
  final bool isEdited;
  final bool hasRepliedMessage;
  final bool hasAttachments;
  final bool displayBottomStatuses;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasRepliedMessage)
                RepliedMessageBubble(
                  message: message,
                  onTap: onRepliedMessageTap,
                ),
              if (displayBottomStatuses)
                Padding(
                  padding: !hasRepliedMessage
                      ? EdgeInsets.zero
                      : const EdgeInsets.only(top: AppSpacing.xs),
                  child: MessageTextBubble(
                    message: message,
                    isMine: isMine,
                    isOnlyEmoji: message.message.isOnlyEmoji,
                  ),
                )
              else
                TextMessageWidget(
                  text: message.message,
                  spacing: AppSpacing.md,
                  textStyle: context.bodyLarge?.apply(
                    color: effectiveTextColor,
                  ),
                  // Time + read state now sit under the bubble, not inline.
                  child: const SizedBox.shrink(),
                ),
              if (hasAttachments) ParseAttachments(message: message),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageSharedPost extends StatelessWidget {
  const MessageSharedPost({
    required this.sharedPost,
    required this.effectiveTextColor,
    required this.isEdited,
    required this.message,
    super.key,
  });

  final PostBlock sharedPost;
  final Color effectiveTextColor;
  final bool isEdited;
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Tappable(
          onTap: () => context.pushNamed(
            AppRoutes.post.name,
            pathParameters: {'id': sharedPost.id},
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                horizontalTitleGap: AppSpacing.sm,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                leading: UserProfileAvatar(
                  avatarUrl: sharedPost.author.avatarUrl,
                  isLarge: false,
                ),
                title: Text(
                  sharedPost.author.username,
                  style: context.bodyLarge?.copyWith(
                    fontWeight: AppFontWeight.bold,
                    color: effectiveTextColor,
                  ),
                ),
              ),
              Stack(
                children: [
                  MessageSharedPostImage(sharedPost: sharedPost),
                  Positioned(
                    top: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: Builder(
                      builder: (_) {
                        if (sharedPost.isReel) {
                          return Assets.icons.instagramReel.svg(
                            height: AppSize.iconSizeBig,
                            width: AppSize.iconSizeBig,
                            colorFilter: const ColorFilter.mode(
                              AppColors.white,
                              BlendMode.srcIn,
                            ),
                          );
                        }
                        if (sharedPost.media.length > 1) {
                          return const Icon(
                            Icons.layers,
                            size: AppSize.iconSizeBig,
                            shadows: [Shadow(blurRadius: 2)],
                          );
                        }
                        if (sharedPost.hasBothMediaTypes) {
                          return const SizedBox.shrink();
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
              if (sharedPost.caption.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Text.rich(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: sharedPost.author.username,
                          style: context.bodyLarge?.copyWith(
                            fontWeight: AppFontWeight.bold,
                            color: effectiveTextColor,
                          ),
                        ),
                        const WidgetSpan(child: Gap.h(AppSpacing.xs)),
                        TextSpan(
                          text: sharedPost.caption,
                          style: context.bodyLarge?.apply(
                            color: effectiveTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageSharedPostImage extends StatelessWidget {
  const MessageSharedPostImage({required this.sharedPost, super.key});

  final PostBlock sharedPost;

  @override
  Widget build(BuildContext context) {
    final screenWidth = (context.screenWidth * .85) - AppSpacing.md * 2;
    final pixelRatio = context.devicePixelRatio;

    final thumbnailWidth = (screenWidth * pixelRatio) ~/ 1;
    return AspectRatio(
      aspectRatio: 1,
      child: ImageAttachmentThumbnail(
        resizeHeight: thumbnailWidth,
        image: Attachment(imageUrl: sharedPost.firstMediaUrl),
        fit: BoxFit.cover,
      ),
    );
  }
}

/// A shared story preview inside a chat bubble: author + a square thumbnail.
/// Tapping opens the story viewer with just this story.
class MessageSharedStory extends StatelessWidget {
  const MessageSharedStory({required this.story, super.key});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final screenWidth = (context.screenWidth * .85) - AppSpacing.md * 2;
    final thumbnailWidth = (screenWidth * context.devicePixelRatio) ~/ 1;
    return Tappable(
      onTap: () => context.pushNamed(
        AppRoutes.stories.name,
        pathParameters: {'user_id': story.author.id},
        extra: StoriesProps(stories: [story], author: story.author),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            horizontalTitleGap: AppSpacing.sm,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            leading: UserProfileAvatar(
              avatarUrl: story.author.avatarUrl,
              isLarge: false,
            ),
            title: Text(
              story.author.username ?? '',
              style: context.bodyLarge?.copyWith(
                fontWeight: AppFontWeight.bold,
                color: AppColors.white,
              ),
            ),
            subtitle: Text(
              context.l10n.storyText,
              style: context.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ImageAttachmentThumbnail(
                  resizeHeight: thumbnailWidth,
                  image: Attachment(imageUrl: story.contentUrl),
                  fit: BoxFit.cover,
                ),
              ),
              if (story.contentType == StoryContentType.video)
                const Icon(
                  Icons.play_circle_outline,
                  size: 44,
                  color: AppColors.white,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MessageSharedReel extends StatelessWidget {
  const MessageSharedReel({
    required this.sharedPost,
    required this.effectiveTextColor,
    required this.isEdited,
    required this.message,
    super.key,
  });

  final PostBlock sharedPost;
  final Color effectiveTextColor;
  final bool isEdited;
  final Message message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Tappable(
          onTap: () => context.pushNamed(
            AppRoutes.post.name,
            pathParameters: {'id': sharedPost.id},
          ),
          child: Stack(
            children: [
              InViewNotifierWidget(
                id: message.id,
                builder: (context, isInView, _) {
                  return InlineVideo(
                    videoSettings: VideoSettings.build(
                      aspectRatio: 1,
                      shouldPlay: isInView,
                      id: sharedPost.id,
                      blurHash: sharedPost.firstMedia?.blurHash,
                      videoUrl: sharedPost.firstMedia?.url,
                      withSound: false,
                      withPlayerController: false,
                      withSoundButton: false,
                    ),
                  );
                },
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Builder(
                  builder: (_) {
                    if (sharedPost.media.length > 1) {
                      return const Icon(
                        Icons.layers,
                        size: AppSize.iconSizeBig,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                child: ListTile(
                  horizontalTitleGap: AppSpacing.sm,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  leading: UserProfileAvatar(
                    avatarUrl: sharedPost.author.avatarUrl,
                    isLarge: false,
                  ),
                  title: Text(
                    sharedPost.author.username,
                    style: context.bodyLarge?.copyWith(
                      fontWeight: AppFontWeight.bold,
                      color: effectiveTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Assets.icons.instagramReel.svg(
                    height: AppSize.iconSizeBig,
                    width: AppSize.iconSizeBig,
                    colorFilter: const ColorFilter.mode(
                      AppColors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageSharedPostUnavailable extends StatelessWidget {
  const MessageSharedPostUnavailable({
    required this.effectiveTextColor,
    required this.message,
    required this.isEdited,
    super.key,
  });

  final Message message;
  final bool isEdited;
  final Color effectiveTextColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.postUnavailableText,
            style: context.bodyLarge?.copyWith(
              fontWeight: AppFontWeight.bold,
              color: effectiveTextColor,
            ),
          ),
          TextMessageWidget(
            text: '${l10n.postUnavailableDescriptionText}.',
            spacing: AppSpacing.md,
            textStyle: context.bodyLarge?.apply(color: effectiveTextColor),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class MessageStatuses extends StatelessWidget {
  const MessageStatuses({
    required this.isEdited,
    required this.message,
    super.key,
  });

  final Message message;
  final bool isEdited;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);
    final isMine = message.sender?.id == user.id;

    // Both wall-clock times (see markConversationRead / sendMessage); normalise
    // to naive local fields so a 'Z'-vs-none label can't skew the compare.
    final otherReadAt = context.select(
      (ChatBloc bloc) => bloc.state.otherReadAt,
    );
    DateTime wall(DateTime d) =>
        DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
    final read =
        otherReadAt != null &&
        !wall(message.createdAt).isAfter(wall(otherReadAt));

    // Both bubbles are the same grey now, so the timestamp reads the same on
    // either side — muted, as the design shows it.
    const effectiveSecondaryTextColor = AppColors.textThird;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isEdited)
          Text(
            context.l10n.editedText,
            style: context.bodySmall?.apply(color: effectiveSecondaryTextColor),
          ),
        gapW4,
        Text(
          message.createdAt.format(context, dateFormat: DateFormat.Hm),
          style: context.bodySmall?.apply(color: effectiveSecondaryTextColor),
        ),
        gapW4,
        if (isMine)
          // One check = sent, two checks (white) = read by the recipient.
          Icon(
            read ? Icons.done_all : Icons.check,
            size: AppSize.iconSizeSmall,
            color: read ? AppColors.white : effectiveSecondaryTextColor,
          ),
      ],
    );
  }
}

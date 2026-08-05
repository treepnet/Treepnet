import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:instagram_blocks_ui/src/like_button.dart';
import 'package:instagram_blocks_ui/src/post_large/post_caption.dart';
import 'package:shared/shared.dart';

class PostFooter extends StatelessWidget {
  const PostFooter({
    required this.block,
    required this.indicatorValue,
    required this.mediasUrl,
    required this.isLiked,
    required this.likePost,
    required this.isBookmarked,
    required this.bookmarkPost,
    required this.commentsCount,
    required this.onAvatarTap,
    required this.onUserTap,
    required this.onCommentsTap,
    required this.onPostShareTap,
    super.key,
    this.likersInFollowingsBuilder,
    this.likesCountBuilder,
  });

  final PostBlock block;
  final ValueNotifier<int> indicatorValue;
  final bool isLiked;
  final bool isBookmarked;
  final VoidCallback bookmarkPost;
  final int commentsCount;
  final VoidCallback likePost;
  final List<String> mediasUrl;
  final ValueSetter<String?> onAvatarTap;
  final ValueSetter<String> onUserTap;
  final ValueSetter<bool> onCommentsTap;
  final OnPostShareTap onPostShareTap;
  final LikesCountBuilder? likesCountBuilder;
  final LikersInFollowingsBuilder? likersInFollowingsBuilder;

  @override
  Widget build(BuildContext context) {
    final isSponsored = block is PostSponsoredBlock;
    final author = block.author;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSponsored)
          SponsoredPostAction(
            imageUrl: block.firstMedia?.url,
            onTap: () => onAvatarTap.call(author.avatarUrl),
          ),
        gapH8,
        // Design: the four actions are spread evenly across the full width —
        // like on the far left, bookmark on the far right — each with its
        // count inline.
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LikeButton(isLiked: isLiked, onLikedTap: likePost),
                  if (likesCountBuilder != null) ...[
                    const Gap.h(AppSpacing.xs),
                    likesCountBuilder!.call(onUserTap),
                  ],
                ],
              ),
              _PostAction(
                onTap: () => onPostShareTap(block.id, block.author),
                icon: _FigmaIcon(asset: Assets.icons.shareLined),
              ),
              _PostAction(
                onTap: () => onCommentsTap(true),
                count: commentsCount,
                icon: _FigmaIcon(asset: Assets.icons.commentLined),
              ),
              _PostAction(
                onTap: bookmarkPost,
                icon: _FigmaIcon(
                  asset: isBookmarked
                      ? Assets.icons.savedFilled
                      : Assets.icons.savedLined,
                ),
              ),
            ],
          ),
        ),
        gapH8,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PostCaption(
                username: author.username,
                caption: block.caption,
                onUserProfileAvatarTap: () =>
                    onAvatarTap.call(author.avatarUrl),
              ),
              if (!isSponsored) TimeAgo(createdAt: block.createdAt),
              gapH8,
            ],
          ),
        ),
      ],
    );
  }
}

/// An icon from the Figma set, tinted to the current foreground colour.
class _FigmaIcon extends StatelessWidget {
  const _FigmaIcon({required this.asset});

  final SvgGenImage asset;

  @override
  Widget build(BuildContext context) {
    return asset.svg(
      width: AppSize.iconSizeMedium,
      height: AppSize.iconSizeMedium,
      colorFilter: ColorFilter.mode(context.adaptiveColor, BlendMode.srcIn),
    );
  }
}

/// An icon with its count beside it, as the design lays the post actions out.
class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.onTap, this.count});

  final Widget icon;
  final VoidCallback onTap;

  /// Omitted for actions the app keeps no counter for (share, bookmark).
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (count != null && count! > 0) ...[
            const Gap.h(AppSpacing.xs),
            Text(
              '$count',
              style: context.titleMedium?.copyWith(
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SponsoredPostAction extends StatelessWidget {
  const SponsoredPostAction({
    required this.onTap,
    required this.imageUrl,
    super.key,
  });

  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      backgroundColor: Colors.transparent,
      fadeStrength: FadeStrength.sm,
      onTap: onTap,
      child: AnimatedContainer(
        duration: 1700.ms,
        curve: Curves.easeInCubic,
        width: double.infinity,
        color: context.customReversedAdaptiveColor(
          dark: AppColors.deepBlue,
          light: AppColors.lightBlue,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              BlockSettings()
                  .postTextDelegate
                  .visitSponsoredInstagramProfileText,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: context.titleMedium?.copyWith(
                fontWeight: AppFontWeight.semiBold,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: AppSize.iconSizeSmall,
            ),
          ],
        ),
      ),
    );
  }
}

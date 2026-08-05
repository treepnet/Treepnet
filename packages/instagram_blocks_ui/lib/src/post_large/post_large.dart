// ignore_for_file: avoid_positional_boolean_parameters
// ignore_for_file: use_setters_to_change_properties

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/src/carousel_dot_indicator.dart';
import 'package:instagram_blocks_ui/src/post_large/post_footer.dart';
import 'package:instagram_blocks_ui/src/post_large/post_header.dart';
import 'package:instagram_blocks_ui/src/post_large/post_media.dart';
import 'package:shared/shared.dart';

typedef AvatarBuilder =
    Widget Function(
      BuildContext context,
      PostAuthor author,
      ValueSetter<String?>? onAvatarTap,
    );

typedef LikesCountBuilder = Widget Function(ValueSetter<String> onUserTap);

typedef LikersInFollowingsBuilder = Widget Function();

typedef OnPostShareTap = void Function(String postId, PostAuthor author);

typedef VideoPlayerBuilder =
    Widget Function(
      BuildContext context,
      VideoMedia media,
      double aspectRatio,
      bool shouldPlay,
    );

class PostLarge extends StatefulWidget {
  const PostLarge({
    required this.block,
    required this.isOwner,
    required this.isLiked,
    required this.likePost,
    required this.isBookmarked,
    required this.bookmarkPost,
    required this.commentsCount,
    required this.isFollowed,
    required this.follow,
    required this.enableFollowButton,
    required this.onCommentsTap,
    required this.onPostShareTap,
    required this.onPressed,
    required this.onUserTap,
    required this.withInViewNotifier,
    required this.postOptionsSettings,
    this.postAuthorAvatarBuilder,
    this.authorBadge,
    this.authorSubtitle,
    this.videoPlayerBuilder,
    this.postIndex,
    this.likesCountBuilder,
    super.key,
    this.likersInFollowingsBuilder,
  });

  final PostBlock block;
  final bool isOwner;
  final bool isFollowed;
  final VoidCallback follow;
  final bool isLiked;
  final VoidCallback likePost;
  final bool isBookmarked;
  final VoidCallback bookmarkPost;
  final int commentsCount;
  final bool enableFollowButton;
  final BlockActionCallback onPressed;
  final ValueSetter<bool> onCommentsTap;
  final OnPostShareTap onPostShareTap;
  final ValueSetter<String> onUserTap;
  final PostOptionsSettings postOptionsSettings;
  final AvatarBuilder? postAuthorAvatarBuilder;

  /// Badge shown beside the author's name; see `PostHeader.authorBadge`.
  final Widget? authorBadge;

  /// Line under the author's name; see `PostHeader.authorSubtitle`.
  final Widget? authorSubtitle;
  final VideoPlayerBuilder? videoPlayerBuilder;
  final int? postIndex;
  final bool withInViewNotifier;
  final LikesCountBuilder? likesCountBuilder;
  final LikersInFollowingsBuilder? likersInFollowingsBuilder;

  @override
  State<PostLarge> createState() => _PostLargeState();
}

class _PostLargeState extends State<PostLarge> {
  late ValueNotifier<int> _indicatorValue;

  @override
  void initState() {
    super.initState();
    _indicatorValue = ValueNotifier(0);
  }

  @override
  void dispose() {
    _indicatorValue.dispose();
    super.dispose();
  }

  void _updateCurrentIndex(int index) => _indicatorValue.value = index;

  void _onAvatarTap() {
    if (!widget.block.hasNavigationAction) return;
    widget.onPressed(widget.block.action!);
  }

  @override
  Widget build(BuildContext context) {
    final isSponsored = widget.block is PostSponsoredBlock;

    final postMedia = PostMedia(
      isLiked: widget.isLiked,
      media: widget.block.media,
      likePost: widget.likePost,
      onPageChanged: _updateCurrentIndex,
      videoPlayerBuilder: widget.videoPlayerBuilder,
      postIndex: widget.postIndex,
      withInViewNotifier: widget.withInViewNotifier,
    );

    Widget postHeader({Color? color}) => PostHeader(
      follow: widget.follow,
      block: widget.block,
      color: color,
      isOwner: widget.isOwner,
      isSponsored: isSponsored,
      isFollowed: widget.isFollowed,
      enableFollowButton: widget.enableFollowButton,
      postAuthorAvatarBuilder: widget.postAuthorAvatarBuilder,
      authorBadge: widget.authorBadge,
      authorSubtitle: widget.authorSubtitle,
      postOptionsSettings: widget.postOptionsSettings,
      onAvatarTap: (_) => _onAvatarTap.call(),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.block.isReel)
          Stack(
            children: [
              postMedia,
              postHeader(color: Colors.white),
            ],
          )
        else ...[
          postHeader(),
          // Figma: the photo is full-bleed with a corner radius of 0, and the
          // carousel dots ride on the photo itself, bottom-centre.
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              postMedia,
              if (widget.block.mediaUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ValueListenableBuilder(
                    valueListenable: _indicatorValue,
                    builder: (context, index, child) => CarouselDotIndicator(
                      mediaCount: widget.block.mediaUrls.length,
                      activeMediaIndex: index,
                    ),
                  ),
                ),
            ],
          ),
        ],
        PostFooter(
          block: widget.block,
          indicatorValue: _indicatorValue,
          mediasUrl: widget.block.mediaUrls,
          isLiked: widget.isLiked,
          likePost: widget.likePost,
          isBookmarked: widget.isBookmarked,
          bookmarkPost: widget.bookmarkPost,
          commentsCount: widget.commentsCount,
          onAvatarTap: (_) => _onAvatarTap(),
          onUserTap: widget.onUserTap,
          onCommentsTap: widget.onCommentsTap,
          onPostShareTap: widget.onPostShareTap,
          likesCountBuilder: widget.likesCountBuilder,
          likersInFollowingsBuilder: widget.likersInFollowingsBuilder,
        ),
      ],
    );

    if (widget.block.isReel) {
      return content;
    }

    // Figma separates posts with a single 1px rule in the border colour —
    // no card, no margin, no shadow.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.borderOutline,
        ),
      ],
    );
  }
}

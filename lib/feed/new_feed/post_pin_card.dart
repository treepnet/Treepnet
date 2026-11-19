import 'dart:ui' show lerpDouble;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/pin_card_place.dart';
import 'package:treepnet/feed/post/widgets/post_popup_dialog.dart'
    show LikeAnimatedIcon;

/// A post on its pin: on Trends ([photoOnly]) its first photo alone (a
/// video's first frame), small, white-edged; on the new feed its card — the
/// photo and the feed card's buttons under it (like and comment with their
/// counts, share, save) on the switch's grey. [grown] (0 on the pin, 1
/// across the globe) takes it to the profile grid's long-press card's size,
/// the buttons coming in under a lone photo; once [big], the full photo and
/// the video playing.
class PostPinCard extends StatelessWidget {
  const PostPinCard({
    required this.block,
    required this.isLiked,
    required this.isBookmarked,
    required this.likesCount,
    required this.commentsCount,
    this.grown = 0,
    this.big = false,
    this.photoOnly = false,
    this.heart,
    this.playVideo = false,
    this.videoPaused = false,
    this.onPhotoTap,
    this.onLikeTap,
    this.onShareTap,
    this.onCommentsTap,
    this.onSaveTap,
    super.key,
  });

  final PostBlock block;
  final bool isLiked;
  final bool isBookmarked;
  final int likesCount;
  final int commentsCount;

  /// How far grown: 0 small, 1 grown.
  final double grown;

  /// Grown or growing: the full photo.
  final bool big;

  /// On its pin, the photo alone (Trends'), not the card.
  final bool photoOnly;

  /// The popping heart of a like.
  final AnimationController? heart;

  /// Grown: its video (a reel's) on, playing unless [videoPaused].
  final bool playVideo;

  /// Its list off screen (another tab shown): the video waits, at its start,
  /// and goes on from there when the list is back — not loaded again.
  final bool videoPaused;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onSaveTap;

  /// Behind the buttons: the grey of the feed switch's pill.
  static const Color footerColor = AppColors.inputSpace;

  /// The grown card's buttons' row (the long-press card's).
  static const double bigFooterHeight = 52;

  /// How wide the small photo is decoded: the grown card's photo shows that
  /// copy, already decoded, while its full one comes (no blur in between).
  int get _smallDecodeWidth => photoOnly ? 240 : 480;

  Widget _button(
    BuildContext context,
    String name,
    VoidCallback? onTap,
    SvgGenImage icon, {
    required double size,
    required double countSize,
    Color? color,
    int count = 0,
  }) => Expanded(
    child: GestureDetector(
      key: ValueKey('pinCard$name'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        // The whole button's height takes the tap; a long count shrinks to
        // its button rather than spill over.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon.svg(
                  width: size,
                  height: size,
                  colorFilter: ColorFilter.mode(
                    color ?? context.adaptiveColor,
                    BlendMode.srcIn,
                  ),
                ),
                if (count > 0) ...[
                  SizedBox(width: size / 6),
                  Text(
                    '$count',
                    style: context.bodySmall?.copyWith(
                      fontSize: countSize,
                      fontWeight: AppFontWeight.semiBold,
                      color: context.adaptiveColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = grown;
    final radius = BorderRadius.circular(
      lerpDouble(photoOnly ? 10 : 12, 16, t)!,
    );
    final footer = lerpDouble(
      photoOnly ? 0 : PinCardPlace.cardFooterHeight,
      bigFooterHeight,
      t.clamp(0.0, 1.0),
    )!;
    // Trends' small photo's white edge, gone as it grows.
    final edge = photoOnly ? (1 - t).clamp(0.0, 1.0) : 0.0;
    final icon = lerpDouble(18, 28, t)!;
    final countSize = lerpDouble(12, 15, t)!;
    final video = block.firstMedia is VideoMedia;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: edge <= 0
            ? null
            : Border.all(
                color: AppColors.white.withValues(alpha: edge),
                width: 2,
              ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: footerColor,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            children: [
              GestureDetector(
                onTap: onPhotoTap,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (big)
                        // The full photo, over the small one while it comes.
                        BlurHashImageThumbnail(
                          id: block.id,
                          decodeWidth: 1080,
                          url: block.firstMediaUrl ?? '',
                          previewUrl: block.firstMediaThumbUrl,
                          previewAlsoAt: _smallDecodeWidth,
                          blurHash: block.firstMedia?.blurHash,
                        )
                      else
                        BlurHashImageThumbnail(
                          id: block.id,
                          decodeWidth: _smallDecodeWidth,
                          url: block.firstMediaThumbUrl ?? '',
                          blurHash: block.firstMedia?.blurHash,
                        ),
                      if (big && video && playVideo)
                        InlineVideo(
                          videoSettings: VideoSettings.build(
                            // Its own: the grid's reels have none, and one
                            // detector key for all mixed up their
                            // seen/unseen.
                            id: 'postPinCard:${block.id}',
                            videoUrl: block.firstMedia?.url ?? '',
                            blurHash: block.firstMedia?.blurHash,
                            aspectRatio: 1,
                            withPlayerController: false,
                            shouldPlay: !videoPaused,
                          ),
                        ),
                      if (heart case final heart?)
                        LikeAnimatedIcon(controller: heart),
                    ],
                  ),
                ),
              ),
              // The buttons: on the new feed's card always; on Trends only as
              // it grows (on the pin, the photo alone).
              if (footer >= 1)
                SizedBox(
                  height: footer,
                  child: Opacity(
                    opacity: photoOnly ? t.clamp(0.0, 1.0) : 1,
                    child: Row(
                      children: [
                        _button(
                          context,
                          'Like',
                          onLikeTap,
                          isLiked
                              ? Assets.icons.heartFilled
                              : Assets.icons.heartLined,
                          size: icon,
                          countSize: countSize,
                          color: isLiked ? AppColors.pink : null,
                          count: likesCount,
                        ),
                        _button(
                          context,
                          'Share',
                          onShareTap,
                          Assets.icons.shareLined,
                          size: icon,
                          countSize: countSize,
                        ),
                        _button(
                          context,
                          'Comment',
                          onCommentsTap,
                          Assets.icons.commentLined,
                          size: icon,
                          countSize: countSize,
                          count: commentsCount,
                        ),
                        _button(
                          context,
                          'Save',
                          onSaveTap,
                          isBookmarked
                              ? Assets.icons.savedFilled
                              : Assets.icons.savedLined,
                          size: icon,
                          countSize: countSize,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Another of the author's posts on its pin (Trends): its small photo,
/// white-edged (more faintly than the post's own). A picture: a drag over it
/// turns the globe; its taps are told by a listener over the photos.
class OtherPinPhoto extends StatelessWidget {
  const OtherPinPhoto({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return IgnorePointer(
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: AppColors.white.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PostPinCard.footerColor,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BlurHashImageThumbnail(url: url, decodeWidth: 240),
          ),
        ),
      ),
    );
  }
}

/// The new feed's small card's arrow, pointing down at the pin, in the grey
/// of the card's buttons' row it hangs from.
class PinArrow extends StatelessWidget {
  const PinArrow({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _ArrowPainter(PostPinCard.footerColor));
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => oldDelegate.color != color;
}

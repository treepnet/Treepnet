import 'dart:ui';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart' hide NumDurationExtension;
import 'package:sprung/sprung.dart';

class PostPopupDialog extends StatelessWidget {
  const PostPopupDialog({
    required this.block,
    required this.popupDialogAnimationController,
    required this.likeIconAnimationController,
    required this.messageVisibility,
    required this.messageText,
    required this.messagePositionLeft,
    required this.likeButtonKey,
    required this.commentOrViewProfileButtonKey,
    required this.sharePostKey,
    required this.saveKey,
    required this.showComments,
    required this.onDismiss,
    this.showAuthor = true,
    this.onAuthorTap,
    required this.onLikeTap,
    required this.onCommentOrViewProfileTap,
    required this.onShareTap,
    required this.onSaveTap,
    super.key,
  });

  final PostBlock block;
  final AnimationController popupDialogAnimationController;
  final AnimationController likeIconAnimationController;
  final ValueNotifier<bool> messageVisibility;
  final ValueNotifier<String> messageText;
  final ValueNotifier<double> messagePositionLeft;
  final GlobalKey likeButtonKey;
  final GlobalKey commentOrViewProfileButtonKey;
  final GlobalKey sharePostKey;
  final GlobalKey saveKey;
  final bool showComments;

  /// The author row above the photo; without it the photo starts at the
  /// card's top.
  final bool showAuthor;

  /// A tap on the author's avatar or name: their profile.
  final VoidCallback? onAuthorTap;

  /// A tap outside the card, or Back: the card goes. It stays open once the
  /// finger lets go off the buttons, so its buttons can be tapped.
  final VoidCallback onDismiss;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentOrViewProfileTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;

  @override
  Widget build(BuildContext context) {
    return BackButtonListener(
      onBackButtonPressed: () async {
        onDismiss();
        return true;
      },
      child: SafeArea(
        child: RepaintBoundary(
          child: AnimatedPopupDialog(
            controller: popupDialogAnimationController,
            onBarrierTap: onDismiss,
            child: Container(
              // The photo's corners follow the card's when nothing is above it.
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // The app's own background: the card's header and buttons sat
                // on a near-white band around the photo.
                color: context.theme.scaffoldBackgroundColor,
              ),
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showAuthor)
                      PopupDialogHeader(block: block, onTap: onAuthorTap),
                    PopupDialogBody(
                      block: block,
                      messageVisibility: messageVisibility,
                      messageText: messageText,
                      messagePositionLeft: messagePositionLeft,
                      likeIconAnimationController: likeIconAnimationController,
                    ),
                    PopupDialogFooter(
                      likeButtonKey: likeButtonKey,
                      commentOrViewProfileButtonKey:
                          commentOrViewProfileButtonKey,
                      showComments: showComments,
                      sharePostKey: sharePostKey,
                      saveKey: saveKey,
                      onLikeTap: onLikeTap,
                      onCommentOrViewProfileTap: onCommentOrViewProfileTap,
                      onShareTap: onShareTap,
                      onSaveTap: onSaveTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PopupDialogHeader extends StatelessWidget {
  const PopupDialogHeader({required this.block, this.onTap, super.key});

  final PostBlock block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxxs,
      ),
      horizontalTitleGap: AppSpacing.sm,
      leading: UserProfileAvatar(
        resizeHeight: 108,
        avatarUrl: block.author.avatarUrl,
        isLarge: false,
        enableBorder: false,
      ),
      title: NameWithBadge(
        userId: block.author.id,
        name: block.author.username,
        style: context.bodyLarge,
      ),
    );
  }
}

class PopupDialogBody extends StatelessWidget {
  const PopupDialogBody({
    required this.block,
    required this.messageVisibility,
    required this.messageText,
    required this.messagePositionLeft,
    required this.likeIconAnimationController,
    super.key,
  });

  final PostBlock block;
  final ValueNotifier<bool> messageVisibility;
  final ValueNotifier<String> messageText;
  final ValueNotifier<double> messagePositionLeft;
  final AnimationController likeIconAnimationController;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (block.firstMedia is ImageMedia)
          PostPopupImage(block: block)
        else
          InlineVideo(
            videoSettings: VideoSettings.build(
              videoUrl: block.firstMedia?.url ?? '',
              blurHash: block.firstMedia?.blurHash,
              withPlayerController: false,
              shouldPlay: true,
            ),
          ),
        AnimatedBuilder(
          animation: Listenable.merge([
            messageVisibility,
            messageText,
            messagePositionLeft,
          ]),
          builder: (context, _) {
            return _PopupMessageDialog(
              visible: messageVisibility.value,
              message: messageText.value,
              widgetPositionLeft: messagePositionLeft.value,
            );
          },
        ),
        LikeAnimatedIcon(controller: likeIconAnimationController),
      ],
    );
  }
}

class PostPopupImage extends StatelessWidget {
  const PostPopupImage({required this.block, super.key});

  final PostBlock block;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: BlurHashImageThumbnail(
        id: block.id,
        decodeWidth: 1080,
        url: block.firstMediaUrl ?? '',
        blurHash: block.firstMedia?.blurHash,
      ),
    );
  }
}

class PopupDialogFooter extends StatelessWidget {
  const PopupDialogFooter({
    required this.likeButtonKey,
    required this.commentOrViewProfileButtonKey,
    required this.showComments,
    required this.sharePostKey,
    required this.saveKey,
    required this.onLikeTap,
    required this.onCommentOrViewProfileTap,
    required this.onShareTap,
    required this.onSaveTap,
    super.key,
  });

  final GlobalKey<State<StatefulWidget>> likeButtonKey;
  final GlobalKey<State<StatefulWidget>> commentOrViewProfileButtonKey;
  final bool showComments;
  final GlobalKey<State<StatefulWidget>> sharePostKey;
  final GlobalKey<State<StatefulWidget>> saveKey;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentOrViewProfileTap;
  final VoidCallback onShareTap;
  final VoidCallback onSaveTap;

  /// A button that also takes a tap, once the card stays open.
  Widget _tappable(VoidCallback onTap, Widget child) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(AppSpacing.xs), child: child),
  );

  @override
  Widget build(BuildContext context) {
    // The feed card's order: like, share, comment, save.
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _tappable(
            onLikeTap,
            SizedBox(
              key: likeButtonKey,
              child: BlocBuilder<PostBloc, PostState>(
                builder: (context, state) {
                  final isLiked = state.isLiked;

                  // The card's heart (LikeButton): filled pink once liked.
                  return (isLiked
                          ? Assets.icons.heartFilled
                          : Assets.icons.heartLined)
                      .svg(
                        width: 28,
                        height: 28,
                        colorFilter: ColorFilter.mode(
                          isLiked ? AppColors.pink : context.adaptiveColor,
                          BlendMode.srcIn,
                        ),
                      );
                },
              ),
            ),
          ),
          _tappable(
            onShareTap,
            SizedBox(
              key: sharePostKey,
              child: Assets.icons.shareLined.svg(
                height: 28,
                colorFilter: ColorFilter.mode(
                  context.adaptiveColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          _tappable(
            onCommentOrViewProfileTap,
            SizedBox(
              key: commentOrViewProfileButtonKey,
              child: showComments
                  ? Assets.icons.commentLined.svg(
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        context.adaptiveColor,
                        BlendMode.srcIn,
                      ),
                    )
                  : Assets.icons.user.svg(
                      height: 28,
                      colorFilter: ColorFilter.mode(
                        context.adaptiveColor,
                        BlendMode.srcIn,
                      ),
                    ),
            ),
          ),
          // Save, where an Options target sat that did nothing.
          _tappable(
            onSaveTap,
            SizedBox(
              key: saveKey,
              child: BlocBuilder<PostBloc, PostState>(
                buildWhen: (a, b) => a.isBookmarked != b.isBookmarked,
                builder: (context, state) =>
                    (state.isBookmarked
                            ? Assets.icons.savedFilled
                            : Assets.icons.savedLined)
                        .svg(
                          height: 28,
                          colorFilter: ColorFilter.mode(
                            context.adaptiveColor,
                            BlendMode.srcIn,
                          ),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LikeAnimatedIcon extends StatelessWidget {
  const LikeAnimatedIcon({required this.controller, super.key});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => AnimatedOpacity(
          duration: 50.ms,
          opacity: controller.isAnimating ? 1 : 0,
          // The card's double-tap heart (PoppingIconAnimationOverlay).
          child:
              ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF2A54), Color(0xFFFF781E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                    ),
                  )
                  .animate(autoPlay: false, controller: controller)
                  .scaleXY(
                    end: 1.3,
                    curve: Sprung.custom(damping: 5, stiffness: 85),
                    duration: 350.ms,
                  )
                  .then(delay: 150.ms, curve: Curves.linear)
                  .scaleXY(end: 1 / 1.3, duration: 150.ms)
                  .fadeOut(duration: 150.ms),
        ),
      ),
    );
  }
}

class _PopupMessageDialog extends StatelessWidget {
  const _PopupMessageDialog({
    required this.message,
    required this.visible,
    required this.widgetPositionLeft,
  });

  final String message;
  final bool visible;
  final double widgetPositionLeft;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      child: Positioned(
        bottom: AppSpacing.lg + AppSpacing.xs,
        left: widgetPositionLeft,
        child:
            Container(
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: .7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm - AppSpacing.xxs,
                  ),
                  child: Text(
                    message,
                    style: context.bodyMedium?.apply(color: AppColors.white),
                  ),
                )
                .animate(onComplete: (_) => HapticFeedback.vibrate())
                .moveY(
                  duration: 250.ms,
                  begin: 10,
                  end: 0,
                  curve: Sprung.custom(damping: 7, stiffness: 65),
                ),
      ),
    );
  }
}

class AnimatedPopupDialog extends StatefulWidget {
  const AnimatedPopupDialog({
    required this.child,
    this.controller,
    this.onBarrierTap,
    super.key,
  });

  final AnimationController? controller;
  final Widget child;

  /// A tap on the dimmed area around [child].
  final VoidCallback? onBarrierTap;

  @override
  State<StatefulWidget> createState() => AnimatedPopupDialogState();
}

class AnimatedPopupDialogState extends State<AnimatedPopupDialog>
    with SingleTickerProviderStateMixin, SafeSetStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  late Animation<double> _sigmaBlurXAnimation;
  late Animation<double> _sigmaBlurYAnimation;

  @override
  void initState() {
    super.initState();

    _animationController =
        widget.controller ?? AnimationController(vsync: this);
    _opacityAnimation = Tween<double>(begin: 0, end: 0.6).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutExpo),
    );
    _sigmaBlurXAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutExpo),
    );
    _sigmaBlurYAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutExpo),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _animationController,
      child: ListenableBuilder(
        listenable: _animationController,
        builder: (context, child) {
          return Material(
            color: AppColors.black.withValues(alpha: _opacityAnimation.value),
            child: child,
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBarrierTap,
          child: Center(
            // A tap on the card itself is not one on the dimmed area.
            child: GestureDetector(
              onTap: () {},
              child: widget.child
                  .animate(autoPlay: true, controller: _animationController)
                  .scaleXY(
                    duration: 450.ms,
                    curve: Sprung.custom(damping: 12, stiffness: 60),
                  )
                  .fadeIn(),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _sigmaBlurXAnimation.value * 13,
            sigmaY: _sigmaBlurYAnimation.value * 10,
          ),
          child: child,
        );
      },
    );
  }
}

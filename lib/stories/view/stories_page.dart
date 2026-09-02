import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/widgets/story_footer.dart';
import 'package:treepnet/stories/widgets/pin_story_sheet.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:story_view/story_view.dart';
import 'package:user_repository/user_repository.dart';

class StoriesPage extends StatelessWidget {
  const StoriesPage({required this.props, super.key});

  final StoriesProps props;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => StoriesBloc(
            storiesRepository: context.read<StoriesRepository>(),
          ),
        ),
        // The story viewer sits on the root navigator, outside Home's provider,
        // so it needs its own CreateStoriesBloc for the footer's "+" (add a
        // story) button.
        BlocProvider(
          create: (context) => CreateStoriesBloc(
            storiesRepository: context.read<StoriesRepository>(),
          ),
        ),
      ],
      child: AppScaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        // The story keeps its full height; the keyboard and reply bar float
        // over it like a sheet rather than shrinking the picture.
        resizeToAvoidBottomInset: false,
        body: _DismissKeyboardFirst(child: StoriesView(props: props)),
      ),
    );
  }
}

class StoriesView extends StatefulWidget {
  const StoriesView({required this.props, super.key});

  final StoriesProps props;

  @override
  State<StoriesView> createState() => _StoriesViewState();
}

/// The progress bar's height (`IndicatorHeight.small`).
const double _timerHeight = 2;

/// Empty space the design wants between the timer and the top of the picture.
const double _storyTopGap = 3;

class _StoriesViewState extends State<StoriesView> with SafeSetStateMixin {
  final StoryController _controller = StoryController();

  late ValueNotifier<List<StoryItem>> _storyItems;
  late ValueNotifier<Story> _currentStory;
  late ValueNotifier<DateTime?> _createdAt;
  late ValueNotifier<bool> _showOverlay;
  late ValueNotifier<bool> _wasVisible;

  /// Width / height of the current story image, or null until it decodes. Drives
  /// the top-aligned frame so the picture keeps its editor proportions instead
  /// of being letterboxed with a black bar top and bottom.
  final _storyAspect = ValueNotifier<double?>(null);

  Color? _textColor;

  /// The batch currently playing. Starts as `widget.props` but is replaced in
  /// place each time the viewer rolls on to the next profile or highlight, so
  /// it cannot come from the widget.
  late StoriesProps _props;

  StoriesProps get props => _props;
  final _stories = <Story>[];

  /// Bumped on every swap. [StoryView] only resets its `shown` flags and
  /// restarts playback in `initState`, so without a changing key it would keep
  /// the finished animation controller and the next profile would never play.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _props = widget.props;
    _storyItems = ValueNotifier(<StoryItem>[]);
    _currentStory = ValueNotifier<Story>(Story.empty);
    _createdAt = ValueNotifier<DateTime?>(null);
    _showOverlay = ValueNotifier<bool>(true);
    _wasVisible = ValueNotifier<bool>(false);

    _stories.addAll(props.stories);

    _storyItems.value = props.stories.toStoryItems(_controller);
    _showOverlay.addListener(_showOverlayListener);
  }

  /// Decodes the story image just enough to learn its shape, so the frame can
  /// match it. Video stories (or a failed decode) leave the aspect null and the
  /// frame simply fills, which is the sensible fallback.
  void _resolveStoryAspect(String url) {
    _storyAspect.value = null;
    if (url.isEmpty) return;
    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      if (mounted && info.image.height > 0) {
        _storyAspect.value = info.image.width / info.image.height;
      }
      stream.removeListener(listener);
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  /// Called when the last story of the current batch finishes — which is also
  /// what a forward tap on the last story triggers.
  Future<void> _onStoriesComplete() async {
    final continuation = _props.continuation;
    if (continuation == null) {
      if (mounted && context.canPop()) context.pop();
      return;
    }
    // Hold the playhead while we work out what is next; otherwise the finished
    // story keeps ticking behind the await.
    _controller.pause();
    final next = await continuation();
    if (!mounted) return;
    if (next == null || next.stories.isEmpty) {
      if (context.canPop()) context.pop();
      return;
    }
    setState(() {
      _props = next;
      _stories
        ..clear()
        ..addAll(next.stories);
      _storyItems.value = next.stories.toStoryItems(_controller);
      _generation++;
    });
    // After the swapped-in StoryView has mounted, not before: it reads the
    // controller's playback state on the way up, and we left it paused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.play();
    });
  }

  Future<void> _initColor() async {
    final textColor = await _useWhiteTextColor(
      region: Offset.zero & const Size(40, 40),
    ).then((isWhite) => isWhite ? AppColors.white : AppColors.black);

    safeSetState(() {
      _textColor = textColor;
    });
  }

  Future<bool> _useWhiteTextColor({required Rect region}) async {
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      NetworkImage(_currentStory.value.contentUrl),
      size: const Size(400, 400),
      region: region,
    );

    final dominantColor = paletteGenerator.dominantColor?.color;
    if (dominantColor == null) return false;

    return _useWhiteForeground(dominantColor);
  }

  bool _useWhiteForeground(Color backgroundColor) =>
      1.05 / (backgroundColor.computeLuminance() + 0.05) > 4.5;

  /// True while the reply field is open. Playback stays stopped throughout —
  /// every other play() path checks this, because the keyboard resizing the
  /// tree fires the visibility callback, which used to restart the story out
  /// from under whoever was typing.
  bool _composing = false;

  void _setComposing(bool composing) {
    // setState, not a bare assignment: the scrim below is built from this.
    if (mounted) setState(() => _composing = composing);
    if (composing) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _showOverlayListener() {
    if (_composing) return;
    if (!_showOverlay.value) {
      _controller.pause();
    } else {
      if (!_wasVisible.value) return;
      _controller.play();
    }
  }

  /// The story-owner's "more" menu: Pin story (add to a place / highlight) and
  /// Delete. Moved out of the old bottom-right [StoryOptions] overlay into the
  /// footer; playback pauses while the menu is open and resumes after.
  Future<void> _openStoryMore() async {
    final story = _currentStory.value;
    _controller.pause();
    // Toggle: a story already pinned somewhere offers Unpin instead of Pin.
    final pinned = await context.read<StoriesRepository>().isStoryPinned(
      storyId: story.id,
    );
    if (!mounted) return;
    await context
        .showListOptionsModal(
          options: [
            ModalOption(
              name: pinned
                  ? context.l10n.unpinStoryText
                  : context.l10n.pinStoryText,
              iconData: pinned ? null : Icons.push_pin_outlined,
              // Unpin: the pin with a line struck through it, to read as
              // "remove", not another pin action.
              icon: pinned
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.push_pin_outlined,
                            color: AppColors.white,
                            size: 22,
                          ),
                          Transform.rotate(
                            angle: 0.7853981633974483, // 45°
                            child: Container(
                              width: 28,
                              height: 2,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              onTap: () async {
                if (pinned) {
                  // Remove from every place and highlight, but keep the story.
                  await context.read<StoriesRepository>().unpinStoryEverywhere(
                    storyId: story.id,
                  );
                  if (mounted) _controller.play();
                  return;
                }
                // _setComposing (not a bare pause): it also guards onSeen /
                // onShow, so returning from the map picker or the new-highlight
                // dialog inside the sheet does not resume the story. Playback
                // holds until the sheet closes.
                _setComposing(true);
                try {
                  await showPinStorySheet(
                    context,
                    story: story,
                    userId: context.read<AppBloc>().state.user.id,
                  );
                } finally {
                  if (mounted) _setComposing(false);
                }
              },
            ),
            ModalOption(
              name: context.l10n.deleteText,
              actionTitle: context.l10n.deleteStoryText,
              actionContent: context.l10n.storyDeleteConfirmationText,
              actionYesText: context.l10n.deleteText,
              actionNoText: context.l10n.cancelText,
              icon: Assets.icons.trash.svg(
                height: AppSize.iconSizeMedium,
                colorFilter: const ColorFilter.mode(
                  AppColors.red,
                  BlendMode.srcIn,
                ),
              ),
              distractive: true,
              noAction: (context) {
                context.pop(false);
                _controller.play();
              },
              onTap: () => context.read<StoriesBloc>().add(
                StoriesStoryDeleteRequested(
                  id: story.id,
                  onStoryDeleted: () => _onStoryDeleted(story),
                ),
              ),
            ),
          ],
        )
        .then((option) {
          if (option == null) {
            _controller.play();
            return;
          }
          option.onTap(context);
        });
  }

  void _onStoryDeleted(Story story) {
    final storyIndex = _stories.indexOf(story);
    if (storyIndex == -1) return;
    if (_storyItems.value.length == 1) {
      _storyItems.value
        ..addAll([Story.empty].toStoryItems(_controller))
        ..removeAt(storyIndex);
      _currentStory.value = Story.empty;
      if (context.canPop()) context.pop();
    } else {
      _controller.previous();
      final prevCurrentStoryIndex = _stories.indexOf(_currentStory.value);
      _stories.removeAt(storyIndex);
      _storyItems.value.removeAt(storyIndex);
      final nextStoryIndex = prevCurrentStoryIndex == 0
          ? 0
          : prevCurrentStoryIndex - 1;
      _currentStory.value = _stories.elementAt(nextStoryIndex);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _storyItems.dispose();
    _currentStory.dispose();
    _createdAt.dispose();
    _showOverlay.dispose();
    _storyAspect.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return Stack(
      children: [
        Viewable(
          itemKey: ValueKey(user.id),
          onSeen: () {
            _wasVisible.value = true;
            if (_composing) return;
            if (_controller.playbackNotifier.value == PlaybackState.pause) {
              if (!_wasVisible.value) {
                return;
              }
              if (mounted) _controller.play();
            }
          },
          onUnseen: () {
            if (mounted) _controller.pause();
          },
          child: ValueListenableBuilder(
            valueListenable: _storyItems,
            builder: (context, storyItems, child) {
              // No long-press overlay toggle: holding the screen pauses the
              // story through the player itself (its onTapDown), and the footer
              // must stay visible while paused — so the frame is returned
              // directly rather than wrapped in a gesture that hid it.
              //
              // KeyedSubtree (below) rather than a key on StoryView itself: the
              // package's constructor does not take one, and the point is to
              // force a fresh element so its initState re-runs. Same frame the
              // editor composed on: inset with rounded corners, so what you post
              // is what viewers see rather than a full-bleed crop.
              return Padding(
                  // Full-bleed width: the picture reaches both screen edges,
                  // no side margins. (Full height too — the keyboard floats
                  // over the story rather than shrinking it, so the picture
                  // stays put and the reply bar sits on top.)
                  padding: EdgeInsets.zero,
                  // No outer ClipRRect: the timer bar lives at the very top on
                  // the dark backdrop and must NOT be clipped. The plugin rounds
                  // the picture itself (contentBorderRadius), so the card still
                  // has all four corners rounded while the bar sits free above.
                  //
                  // Top-aligned to the editor proportions: the story fills the
                  // width and starts at the top, so there is never a black bar
                  // above it. Anything taller than the screen is cropped from
                  // the bottom; anything shorter leaves the footer's dark area
                  // below. Falls back to filling the frame until the aspect is
                  // known (and for videos, which do not decode as images).
                  child: LayoutBuilder(
                      builder: (context, constraints) => ValueListenableBuilder<double?>(
                        valueListenable: _storyAspect,
                        builder: (context, aspect, _) {
                          final w = constraints.maxWidth;
                          // Room for the timer plus a 3px gap above the picture.
                          // Added to the box height so the image keeps its full
                          // height and is NOT cropped — the shift eats into the
                          // footer's space below instead.
                          const topReserve = _timerHeight + _storyTopGap;
                          final h =
                              (aspect == null
                                  ? constraints.maxHeight
                                  : w / aspect) +
                              topReserve;
                          return OverflowBox(
                            alignment: Alignment.topCenter,
                            minWidth: w,
                            maxWidth: w,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: SizedBox(
                              width: w,
                              height: h,
                              child: KeyedSubtree(
                                key: ValueKey(_generation),
                                child: StoryView(
                                  inline: true,
                                  // A hairline bar pinned to the very top of the
                                  // story. `small` is the plugin's thinnest
                                  // (2px). A 10px inset on each side — the bar is
                                  // a free sibling above the card, so nothing
                                  // clips its ends.
                                  indicatorHeight: IndicatorHeight.small,
                                  indicatorOuterPadding:
                                      const EdgeInsets.symmetric(horizontal: 10),
                                  // Visible even over a bright photo: the filled
                                  // part is solid white, the track a soft white
                                  // — otherwise only the filled segment showed
                                  // and the bar read as broken.
                                  indicatorForegroundColor: AppColors.white,
                                  indicatorColor: AppColors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                  // Drops only the picture, leaving the bar
                                  // pinned. Matches the box's extra height so
                                  // nothing is cropped: timer height + 3px gap.
                                  contentTopPadding: _timerHeight + _storyTopGap,
                                  // The plugin rounds the picture itself now
                                  // that the outer ClipRRect is gone, so the
                                  // card keeps all four corners rounded.
                                  contentBorderRadius: 25,
                                  storyItems: storyItems,
                                  controller: _controller,
                                  onStoryShow: (story, index) {
                                    // A callback left over from the outgoing profile can land
                                    // after the swap, when the new list may be shorter.
                                    if (index >= _stories.length) return;
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (index >= _stories.length) return;
                                          _currentStory.value = _stories[index];
                                          _createdAt.value =
                                              _stories[index].createdAt;
                                          _resolveStoryAspect(
                                            _stories[index].contentUrl,
                                          );
                                          _initColor();
                                        });
                                    if (props.onStorySeen != null) {
                                      props.onStorySeen!.call(index, _stories);
                                    }
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          context.read<StoriesBloc>().add(
                                            StoriesStorySeen(
                                              _stories[index],
                                              user.id,
                                            ),
                                          );
                                        });
                                    // Record the view for the "seen by" list — but never your
                                    // own story.
                                    final shown = _stories[index];
                                    if (shown.author.id != user.id) {
                                      context
                                          .read<StoriesRepository>()
                                          .recordStoryView(
                                            storyId: shown.id,
                                            viewerId: user.id,
                                          );
                                    }
                                  },
                                  onVerticalSwipeComplete: (_) => context.pop(),
                                  onComplete: _onStoriesComplete,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
              },
            ),
          ),
        // Dims the story while a reply is being typed, so the composer reads
        // as a layer over it rather than part of the picture. It also catches
        // taps: a tap anywhere on the dimmed story closes the keyboard instead
        // of reaching the story's own advance/exit gestures underneath.
        if (_composing)
          Positioned.fill(
            key: const ValueKey('story-scrim'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(context).unfocus(),
              child: ColoredBox(color: AppColors.black.withValues(alpha: 0.6)),
            ),
          ),
        Positioned(
          // Keyed so inserting the scrim above does not shuffle this element
          // and wipe the footer's reply state — that was the "first tap only
          // dims, second tap opens the keyboard" bug.
          key: const ValueKey('story-footer'),
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _showOverlay,
              _currentStory,
              _createdAt,
            ]),
            builder: (context, _) {
              final story = _currentStory.value;
              if (story == null) return const SizedBox.shrink();
              return AnimatedOpacity(
                opacity: _showOverlay.value ? 1 : 0,
                duration: 200.ms,
                child: Padding(
                  // Lifts the bar clear of the keyboard, which no longer
                  // resizes the page.
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: StoryFooter(
                    story: story,
                    author: props.author,
                    viewer: user,
                    onComposing: _setComposing,
                    onMore: _openStoryMore,
                    // Owner-only "+": opens the story camera to add another.
                    // Pause while the camera is up so the current story does not
                    // run out (and close) underneath it.
                    onAddStory: () async {
                      _controller.pause();
                      await startStoryCreation(context, props.author);
                      if (mounted) _controller.play();
                    },
                    // Author sits at the very bottom, on the same line as the
                    // controls — profile, name and "time ago" live in the footer
                    // bar rather than floating up over the picture.
                    leading: StoriesAuthorListTile(
                      author: props.author,
                      createdAt: _createdAt.value,
                      place: story.locationName,
                      dense: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class StoryOptions extends StatelessWidget {
  const StoryOptions({
    required this.currentStory,
    required this.controller,
    required this.author,
    required this.onStoryDeleted,
    this.iconColor,
    super.key,
  });

  final Story currentStory;
  final StoryController controller;
  final User author;
  final ValueSetter<Story> onStoryDeleted;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);
    final isMine = author.id == user.id;

    if (!isMine) return const SizedBox.shrink();

    return Row(
      children: [
        Tappable.faded(
          onTap: () async {
            controller.pause();
            await context
                .showListOptionsModal(
                  options: [
                    ModalOption(
                      name: context.l10n.deleteText,
                      actionTitle: context.l10n.deleteStoryText,
                      actionContent: context.l10n.storyDeleteConfirmationText,
                      actionYesText: context.l10n.deleteText,
                      actionNoText: context.l10n.cancelText,
                      icon: Assets.icons.trash.svg(
                        height: AppSize.iconSizeMedium,
                        colorFilter: const ColorFilter.mode(
                          AppColors.red,
                          BlendMode.srcIn,
                        ),
                      ),
                      distractive: true,
                      noAction: (context) {
                        context.pop(false);
                        controller.play();
                      },
                      onTap: () => context.read<StoriesBloc>().add(
                        StoriesStoryDeleteRequested(
                          id: currentStory.id,
                          onStoryDeleted: () {
                            onStoryDeleted.call(currentStory);
                          },
                        ),
                      ),
                    ),
                  ],
                )
                .then((option) {
                  if (option == null) {
                    controller.play();
                    return;
                  }
                  void onTap() => option.onTap(context);
                  onTap.call();
                });
          },
          child: AnimatedDefaultTextStyle(
            duration: 150.ms,
            style: context.bodyMedium!.copyWith(
              fontWeight: AppFontWeight.bold,
              letterSpacing: 0.4,
              color: iconColor,
            ),
            overflow: TextOverflow.ellipsis,
            child: Column(
              children: [
                Icon(Icons.more_vert_outlined, color: iconColor),
                const Gap.v(AppSpacing.sm),
                Text(context.l10n.moreText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The author block at the foot of a story, per Figma: avatar on the left,
/// then the name with its verified badge, the place the story was taken, and
/// the date — each on its own line.
class StoriesAuthorListTile extends StatelessWidget {
  const StoriesAuthorListTile({
    required this.author,
    required this.createdAt,
    this.place,
    this.dense = false,
    super.key,
  });

  final User author;
  final DateTime? createdAt;

  /// Drops the outer [SafeArea] and padding so the tile can sit inline inside
  /// the footer bar, which supplies its own safe area and padding.
  final bool dense;

  /// Where the story was taken. Treepnet has no audio, so the design's music
  /// line carries the place instead.
  final String? place;

  /// How long ago the story went up, worded exactly like the timestamp under
  /// a post. A calendar date said nothing useful: a story lives 24 hours, so
  /// the question is always "how fresh", never "which day".
  static String _date(BuildContext context, DateTime? at) =>
      at == null ? '' : at.timeAgo(context);

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: AppColors.black, blurRadius: 6)];

    // Left-aligned: avatar, then the name with the time tucked under it.
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
            Tappable.scaled(
              onTap: () => context.pushNamed(
                AppRoutes.userProfile.name,
                pathParameters: {'user_id': author.id},
              ),
              child: UserProfileAvatar(
                isLarge: false,
                radius: 22,
                avatarUrl: author.avatarUrl,
                enableBorder: false,
              ),
            ),
            const Gap.h(AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          author.displayUsername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: AppFontWeight.semiBold,
                            shadows: shadow,
                          ),
                        ),
                      ),
                      const Gap.h(AppSpacing.xs),
                      TravelTierBadge(userId: author.id),
                    ],
                  ),
                  // The place chip under the username is deliberately not shown:
                  // pinning a story to a location must never surface its name
                  // here, in any case.
                  Text(
                    _date(context, createdAt),
                    style: context.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.75),
                      shadows: shadow,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

    if (dense) return content;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: content,
      ),
    );
  }
}

extension on List<Story> {
  List<StoryItem> toStoryItems(StoryController controller) => safeMap(
    (story) => switch (story.contentType) {
      StoryContentType.image => StoryItem.inlineImage(
        url: story.contentUrl,
        shown: story.seen,
        controller: controller,
        duration: 5.seconds,
        roundedTop: false,
      ),
      StoryContentType.video => StoryItem.pageVideo(
        story.contentUrl,
        shown: story.seen,
        controller: controller,
        duration: story.duration == null ? null : (story.duration! * 1000).ms,
      ),
    },
  ).toList();
}

/// Back closes the reply keyboard before it leaves the story.
///
/// Without this, hitting back mid-reply dropped the viewer all the way out to
/// the feed — the keyboard is a layer over the story, so it should peel off
/// first.
class _DismissKeyboardFirst extends StatelessWidget {
  const _DismissKeyboardFirst({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: MediaQuery.viewInsetsOf(context).bottom == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) FocusScope.of(context).unfocus();
      },
      child: child,
    );
  }
}

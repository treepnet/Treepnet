import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';

import '../controller/story_controller.dart';
import '../utils.dart';
import 'story_image.dart';

/// Indicates where the progress indicators should be placed.
enum ProgressPosition { top, bottom, none }

/// This is used to specify the height of the progress indicator. Inline stories
/// should use [small]
enum IndicatorHeight { small, medium, large }

/// This is a representation of a story item (or page).
class StoryItem {
  /// Specifies how long the page should be displayed. It should be a reasonable
  /// amount of time greater than 0 milliseconds.
  final Duration duration;

  /// Has this page been shown already? This is used to indicate that the page
  /// has been displayed. If some pages are supposed to be skipped in a story,
  /// mark them as shown `shown = true`.
  ///
  /// However, during initialization of the story view, all pages after the
  /// last unshown page will have their `shown` attribute altered to false. This
  /// is because the next item to be displayed is taken by the last unshown
  /// story item.
  bool shown;

  /// The page content
  final Widget view;

  /// An image story's loader, so its decoder can be let go ([dispose]).
  /// Null for other kinds.
  final ImageLoader? imageLoader;

  StoryItem(
    this.view, {
    required this.duration,
    this.shown = false,
    this.imageLoader,
  });

  /// Lets go of what the story decoded (its image decoder) once it won't be
  /// shown again. Without it that native memory waited for the garbage
  /// collector while someone flipped through many stories.
  void dispose() => imageLoader?.dispose();

  /// Shorthand for creating inline image. [controller] should be same instance as
  /// one passed to the `StoryView`
  factory StoryItem.inlineImage({
    required String url,
    Text? caption,
    required StoryController controller,
    Key? key,
    BoxFit imageFit = BoxFit.cover,
    Map<String, dynamic>? requestHeaders,
    bool shown = false,
    bool roundedTop = true,
    bool roundedBottom = false,
    Widget? loadingWidget,
    Widget? errorWidget,
    StoryErrorBuilder? errorBuilder,
    EdgeInsetsGeometry? captionOuterPadding,
    Duration? duration,
    ValueChanged<Size>? onImageSize,
  }) {
    final imageLoader = ImageLoader(url, requestHeaders: requestHeaders);
    return StoryItem(
      ClipRRect(
        key: key,
        child: Container(
          color: Colors.grey[100],
          child: Container(
            color: Colors.black,
            child: Stack(
              children: <Widget>[
                StoryImage(
                  imageLoader,
                  controller: controller,
                  fit: imageFit,
                  loadingWidget: loadingWidget,
                  errorWidget: errorWidget,
                  errorBuilder: errorBuilder,
                  onSize: onImageSize,
                ),
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  padding: captionOuterPadding?? EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      child: caption?? const SizedBox.shrink(),
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(roundedTop ? 8 : 0),
          bottom: Radius.circular(roundedBottom ? 8 : 0),
        ),
      ),
      shown: shown,
      duration: duration ?? Duration(seconds: 3),
      imageLoader: imageLoader,
    );
  }
}

/// Widget to display stories just like Whatsapp and Instagram. Can also be used
/// inline/inside [ListView] or [Column] just like Google News app. Comes with
/// gestures to pause, forward and go to previous page.
class StoryView extends StatefulWidget {
  /// The pages to displayed.
  final List<StoryItem?> storyItems;

  /// Callback for when a full cycle of story is shown.
  final VoidCallback? onComplete;

  /// Callback for when a vertical swipe gesture is detected. If you do not
  /// want to listen to such event, do not provide it. For instance,
  /// for inline stories inside ListViews, it is preferrable to not to
  /// provide this callback so as to enable scroll events on the list view.
  final Function(Direction?)? onVerticalSwipeComplete;

  /// Callback for when a story and it index is currently being shown.
  final void Function(StoryItem storyItem, int index)? onStoryShow;

  /// Where the progress indicator should be placed.
  final ProgressPosition progressPosition;


  /// If you would like to display the story as full-page, then set this to
  /// `false`. But in case you would display this as part of a page (eg. in
  /// a [ListView] or [Column]) then set this to `true`.
  final bool inline;

  /// Controls the playback of the stories
  final StoryController controller;

  /// Indicator Color
  final Color? indicatorColor;
  /// Indicator Foreground Color
  final Color? indicatorForegroundColor;

  /// Determine the height of the indicator
  final IndicatorHeight indicatorHeight;

  /// Use this if you want to give outer padding to the indicator
  final EdgeInsetsGeometry indicatorOuterPadding;

  /// Pushes only the media down from the top, leaving the progress bar pinned.
  final double contentTopPadding;

  /// Rounds the media card so the progress bar can sit above it, unclipped.
  final double contentBorderRadius;

  StoryView({
    required this.storyItems,
    required this.controller,
    this.onComplete,
    this.onStoryShow,
    this.progressPosition = ProgressPosition.top,
    this.inline = false,
    this.onVerticalSwipeComplete,
    this.indicatorColor,
    this.indicatorForegroundColor,
    this.indicatorHeight = IndicatorHeight.large,
    this.indicatorOuterPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8,),
    this.contentTopPadding = 0,
    this.contentBorderRadius = 0,
  });

  @override
  State<StatefulWidget> createState() {
    return StoryViewState();
  }
}

class StoryViewState extends State<StoryView> with TickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _currentAnimation;
  Timer? _nextDebouncer;

  StreamSubscription<PlaybackState>? _playbackSubscription;
  StreamSubscription<void>? _rewindSubscription;

  VerticalDragInfo? verticalDragInfo;

  StoryItem? get _currentStory {
    return widget.storyItems.firstWhereOrNull((it) => !it!.shown);
  }

  Widget get _currentView {
    var item = widget.storyItems.firstWhereOrNull((it) => !it!.shown);
    item ??= widget.storyItems.last;
    return item?.view ?? Container();
  }

  @override
  void initState() {
    super.initState();

    // All pages after the first unshown page should have their shown value as
    // false
    final firstPage = widget.storyItems.firstWhereOrNull((it) => !it!.shown);
    if (firstPage == null) {
      widget.storyItems.forEach((it2) {
        it2!.shown = false;
      });
    } else {
      final lastShownPos = widget.storyItems.indexOf(firstPage);
      widget.storyItems.sublist(lastShownPos).forEach((it) {
        it!.shown = false;
      });
    }

    this._playbackSubscription =
        widget.controller.playbackNotifier.listen((playbackStatus) {
      switch (playbackStatus) {
        case PlaybackState.play:
          _removeNextHold();
          this._animationController?.forward();
          break;

        case PlaybackState.pause:
          _holdNext(); // then pause animation
          this._animationController?.stop(canceled: false);
          break;

        case PlaybackState.next:
          _removeNextHold();
          _goForward();
          break;

        case PlaybackState.previous:
          _removeNextHold();
          _goBack();
          break;
      }
    });

    _rewindSubscription = widget.controller.rewinds.listen((_) {
      final controller = _animationController;
      if (controller == null) return;
      final playing = controller.isAnimating;
      // Setting the value stops the animation.
      controller.value = 0;
      if (playing) controller.forward();
    });

    _play();
  }

  @override
  void dispose() {
    _clearDebouncer();

    _animationController?.dispose();
    _playbackSubscription?.cancel();
    _rewindSubscription?.cancel();

    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  void _play() {
    _animationController?.dispose();
    // get the next playing page
    final storyItem = widget.storyItems.firstWhere((it) {
      return !it!.shown;
    })!;

    final storyItemIndex = widget.storyItems.indexOf(storyItem);

    if (widget.onStoryShow != null) {
      widget.onStoryShow!(storyItem, storyItemIndex);
    }

    _animationController =
        AnimationController(duration: storyItem.duration, vsync: this);

    _animationController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        storyItem.shown = true;
        if (widget.storyItems.last != storyItem) {
          _beginPlay();
        } else {
          // done playing
          _onComplete();
        }
      }
    });

    _currentAnimation =
        Tween(begin: 0.0, end: 1.0).animate(_animationController!);

    widget.controller.play();
  }

  void _beginPlay() {
    setState(() {});
    _play();
  }

  void _onComplete() {
    if (widget.onComplete != null) {
      widget.controller.pause();
      widget.onComplete!();
    }
  }

  void _goBack() {
    _animationController!.stop();

    if (this._currentStory == null) {
      widget.storyItems.last!.shown = false;
    }

    if (this._currentStory == widget.storyItems.first) {
      _beginPlay();
    } else {
      this._currentStory!.shown = false;
      int lastPos = widget.storyItems.indexOf(this._currentStory);
      final previous = widget.storyItems[lastPos - 1]!;

      previous.shown = false;

      _beginPlay();
    }
  }

  void _goForward() {
    if (this._currentStory != widget.storyItems.last) {
      _animationController!.stop();

      // get last showing
      final _last = this._currentStory;

      if (_last != null) {
        _last.shown = true;
        if (_last != widget.storyItems.last) {
          _beginPlay();
        }
      }
    } else {
      // this is the last page, progress animation should skip to end
      _animationController!
          .animateTo(1.0, duration: Duration(milliseconds: 10));
    }
  }

  void _clearDebouncer() {
    _nextDebouncer?.cancel();
    _nextDebouncer = null;
  }

  void _removeNextHold() {
    _nextDebouncer?.cancel();
    _nextDebouncer = null;
  }

  void _holdNext() {
    _nextDebouncer?.cancel();
    _nextDebouncer = Timer(Duration(milliseconds: 500), () {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Transparent, not white: the media is now a rounded card inset from the
      // top, so the space above it (behind the progress bar) shows the page's
      // dark background — which is what keeps the bar legible.
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          // The media as a rounded card, pushed below the bar by
          // contentTopPadding. The progress bar is a sibling above it, so it is
          // never clipped by this rounding — it sits over the dark backdrop.
          Padding(
            padding: EdgeInsets.only(top: widget.contentTopPadding),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.contentBorderRadius),
              child: _currentView,
            ),
          ),
          Visibility(
            visible: widget.progressPosition != ProgressPosition.none,
            child: Align(
              alignment: widget.progressPosition == ProgressPosition.top
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              child: SafeArea(
                bottom: widget.inline ? false : true,
                // we use SafeArea here for notched and bezeles phones
                child: Container(
                  padding: widget.indicatorOuterPadding,
                  child: PageBar(
                    widget.storyItems
                        .map((it) => PageData(it!.duration, it.shown))
                        .toList(),
                    this._currentAnimation,
                    key: UniqueKey(),
                    indicatorHeight: widget.indicatorHeight,
                    indicatorColor: widget.indicatorColor,
                    indicatorForegroundColor: widget.indicatorForegroundColor,
                  ),
                ),
              ),
            ),
          ),
          Align(
              alignment: Alignment.centerRight,
              heightFactor: 1,
              child: GestureDetector(
                onTapDown: (details) {
                  widget.controller.pause();
                },
                onTapCancel: () {
                  widget.controller.play();
                },
                onTapUp: (details) {
                  // if debounce timed out (not active) then continue anim
                  if (_nextDebouncer?.isActive == false) {
                    widget.controller.play();
                  } else {
                    widget.controller.next();
                  }
                },
                onVerticalDragStart: widget.onVerticalSwipeComplete == null
                    ? null
                    : (details) {
                        widget.controller.pause();
                      },
                onVerticalDragCancel: widget.onVerticalSwipeComplete == null
                    ? null
                    : () {
                        widget.controller.play();
                      },
                onVerticalDragUpdate: widget.onVerticalSwipeComplete == null
                    ? null
                    : (details) {
                        if (verticalDragInfo == null) {
                          verticalDragInfo = VerticalDragInfo();
                        }

                        verticalDragInfo!.update(details.primaryDelta!);

                        // TODO: provide callback interface for animation purposes
                      },
                onVerticalDragEnd: widget.onVerticalSwipeComplete == null
                    ? null
                    : (details) {
                        widget.controller.play();
                        // finish up drag cycle
                        final info = verticalDragInfo;
                        verticalDragInfo = null;
                        // A quick flick can end before any update came in,
                        // so there is no drag info: its speed tells the way.
                        final velocity = details.primaryVelocity ?? 0;
                        final Direction? direction = info != null
                            ? (info.cancel ? null : info.direction)
                            : velocity > 0
                                ? Direction.down
                                : velocity < 0
                                    ? Direction.up
                                    : null;
                        if (direction != null &&
                            widget.onVerticalSwipeComplete != null) {
                          widget.onVerticalSwipeComplete!(direction);
                        }
                      },
              )),
          Align(
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: SizedBox(
                child: GestureDetector(onTap: () {
                  widget.controller.previous();
                }),
                width: 70),
          ),
        ],
      ),
    );
  }
}

/// Capsule holding the duration and shown property of each story. Passed down
/// to the pages bar to render the page indicators.
class PageData {
  Duration duration;
  bool shown;

  PageData(this.duration, this.shown);
}

/// Horizontal bar displaying a row of [StoryProgressIndicator] based on the
/// [pages] provided.
class PageBar extends StatefulWidget {
  final List<PageData> pages;
  final Animation<double>? animation;
  final IndicatorHeight indicatorHeight;
  final Color? indicatorColor;
  final Color? indicatorForegroundColor;

  PageBar(
    this.pages,
    this.animation, {
    this.indicatorHeight = IndicatorHeight.large,
    this.indicatorColor,
    this.indicatorForegroundColor,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return PageBarState();
  }
}

class PageBarState extends State<PageBar> {
  double spacing = 4;

  void _tick() => setState(() {});

  @override
  void initState() {
    super.initState();

    int count = widget.pages.length;
    spacing = (count > 15) ? 2 : ((count > 10) ? 3 : 4);

    widget.animation!.addListener(_tick);
  }

  @override
  void didUpdateWidget(PageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation?.removeListener(_tick);
      widget.animation?.addListener(_tick);
    }
  }

  /// The bar is rebuilt with a new key on every StoryView rebuild: each one
  /// left its listener on the story's animation, ticking for nothing until
  /// the story ended.
  @override
  void dispose() {
    widget.animation?.removeListener(_tick);
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  bool isPlaying(PageData page) {
    return widget.pages.firstWhereOrNull((it) => !it.shown) == page;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: widget.pages.map((it) {
        return Expanded(
          child: Container(
            padding: EdgeInsets.only(
                right: widget.pages.last == it ? 0 : this.spacing),
            child: StoryProgressIndicator(
              isPlaying(it) ? widget.animation!.value : (it.shown ? 1 : 0),
              indicatorHeight:
                  widget.indicatorHeight == IndicatorHeight.large ? 5 : widget.indicatorHeight == IndicatorHeight.medium ? 3 : 2,
              indicatorColor: widget.indicatorColor,
              indicatorForegroundColor: widget.indicatorForegroundColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Custom progress bar. Supposed to be lighter than the
/// original [ProgressIndicator], and rounded at the sides.
class StoryProgressIndicator extends StatelessWidget {
  /// From `0.0` to `1.0`, determines the progress of the indicator
  final double value;
  final double indicatorHeight;
  final Color? indicatorColor;
  final Color? indicatorForegroundColor;

  StoryProgressIndicator(
    this.value, {
    this.indicatorHeight = 5,
    this.indicatorColor,
    this.indicatorForegroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.fromHeight(
        this.indicatorHeight,
      ),
      foregroundPainter: IndicatorOval(
        this.indicatorForegroundColor?? Colors.white.withValues(alpha: 0.8),
        this.value,
      ),
      painter: IndicatorOval(
        this.indicatorColor?? Colors.white.withValues(alpha: 0.4),
        1.0,
      ),
    );
  }
}

class IndicatorOval extends CustomPainter {
  final Color color;
  final double widthFactor;

  IndicatorOval(this.color, this.widthFactor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = this.color;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.width * this.widthFactor, size.height),
            Radius.circular(3)),
        paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart' hide NumDurationExtension;
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/post/widgets/post_popup_dialog.dart'
    show LikeAnimatedIcon;
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart'
    show TravelCountBadge;

/// Marks the new feed (a prototype): its posts show their author's globe in
/// place of the photos ([FeedPostGlobe]). Posts anywhere else are as ever.
class FeedGlobeMode extends InheritedWidget {
  const FeedGlobeMode({required super.child, super.key});

  /// Whether [context] is inside the new feed.
  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedGlobeMode>() != null;

  @override
  bool updateShouldNotify(FeedGlobeMode oldWidget) => false;
}

/// A post's author's travel globe, 4:5, in place of the post's photos (the
/// new feed): the whole globe as on their profile, turned to the post's
/// place, with how far they have travelled in its top left corner and a
/// small card of the post (as the profile grid's long-press one) standing
/// over its pin. A tap on the card's photo grows it, in its place, to fill
/// the globe's width; another tap on it, a tap anywhere else, or a scroll
/// of the feed shrinks it back. Nothing else changes meanwhile: no dimming.
/// The card carries the post's buttons (the feed card has none under it
/// then). The globe turns and zooms as on the profile, with its +, − and
/// back-to-the-post buttons, the card going round with the post's pin (gone
/// while the pin is round the back); the new feed scrolls by its buttons
/// only, so a drag is always the globe's.
class FeedPostGlobe extends StatefulWidget {
  const FeedPostGlobe({
    required this.block,
    this.isLiked = false,
    this.isBookmarked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
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

  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onSaveTap;

  /// The globe's ground (as [GlobeView] paints it), while it loads.
  static const _ground = Color(0xFF15181B);

  @override
  State<FeedPostGlobe> createState() => _FeedPostGlobeState();
}

class _FeedPostGlobeState extends State<FeedPostGlobe>
    with TickerProviderStateMixin {
  late Future<TravelMap?> _map = _fetch();

  /// The pins as the globe takes them: the same list each build (a new one
  /// would make the globe rebuild its whole scene).
  List<({double lat, double lng, String? name})> _points = const [];

  /// Where the globe was turned to (its opening centre, kept: it reads it
  /// only once), set the first time it shows with the map.
  ({double lat, double lng})? _camera;

  /// Where the post's pin is drawn, worked out again once the map data is in
  /// (a region's pins merge into one; see [GlobeView.zoomedOutPinOf]).
  ({double lat, double lng})? _pinAt;
  bool _pinAtWithRegions = false;

  /// Where the globe looks, and where it draws the post's pin.
  final _globe = GlobeController();

  // --- the card grown ------------------------------------------------------

  /// The card, to tell a tap on it from one elsewhere.
  final _cardKey = GlobalKey();

  /// 0 small, over the pin; 1 grown.
  late final AnimationController _grow;
  late final Animation<double> _growCurve;

  /// The grown card's heart, popping on a like (the long-press card's).
  late final AnimationController _heart;

  /// Grown, or growing.
  bool _big = false;

  /// Where a finger went down while the card is big, to shrink it if that
  /// is a tap off the card (not a scroll).
  Offset? _downAt;
  int? _downPointer;

  Future<TravelMap?> _fetch() async {
    final map = await context.read<PostsRepository>().travelMapOf(
      userId: widget.block.author.id,
    );
    _points = map?.points ?? const [];
    _camera = null;
    _pinAt = null;
    return map;
  }

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _growCurve = CurvedAnimation(
      parent: _grow,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _heart = AnimationController(vsync: this);
    final geo = GeoRegions.instance;
    if (!geo.isLoaded) {
      // Once in, the post's pin merges with its region's: the card follows.
      unawaited(
        geo.load().then((_) {
          if (mounted) setState(() {});
        }, onError: (Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant FeedPostGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.author.id != widget.block.author.id ||
        oldWidget.block.id != widget.block.id) {
      _map = _fetch();
    }
  }

  @override
  void dispose() {
    _listenForTapsOff(false);
    _listenForScroll(false);
    _grow.dispose();
    _heart.dispose();
    _globe.dispose();
    super.dispose();
  }

  ({double lat, double lng})? _drawnPin(TravelMap? map) {
    final pin = map?.pinOf(widget.block.id);
    if (pin == null) return null;
    final withRegions = GeoRegions.instance.isLoaded;
    if (_pinAt == null || withRegions != _pinAtWithRegions) {
      _pinAt = GlobeView.zoomedOutPinOf(_points, (lat: pin.lat, lng: pin.lng));
      _pinAtWithRegions = withRegions;
    }
    return _pinAt;
  }

  void _toggle() => _big ? _shrink() : _expand();

  void _expand() {
    if (_big) return;
    setState(() => _big = true);
    _listenForTapsOff(true);
    _listenForScroll(true);
    unawaited(_grow.forward());
  }

  void _shrink() {
    if (!_big) return;
    setState(() => _big = false);
    _listenForTapsOff(false);
    _listenForScroll(false);
    unawaited(_grow.reverse());
  }

  /// The feed's list while the card is big, and where it stood then.
  ScrollPosition? _scroll;
  double _scrolledFrom = 0;

  /// A scroll of the feed (a drag, a fling, the top bar's scroll to the top)
  /// shrinks the card back.
  void _listenForScroll(bool on) {
    _scroll?.removeListener(_onScroll);
    _scroll = null;
    if (!on) return;
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (position == null) return;
    _scroll = position..addListener(_onScroll);
    _scrolledFrom = position.pixels;
  }

  void _onScroll() {
    final position = _scroll;
    if (position == null) return;
    if ((position.pixels - _scrolledFrom).abs() > 1) _shrink();
  }

  bool _listening = false;

  /// Every tap on the screen, heard without taking it from anything (the
  /// feed still scrolls, buttons still work): one off the card shrinks it.
  void _listenForTapsOff(bool on) {
    if (on == _listening) return;
    _listening = on;
    final router = GestureBinding.instance.pointerRouter;
    if (on) {
      router.addGlobalRoute(_onPointer);
    } else {
      router.removeGlobalRoute(_onPointer);
      _downAt = null;
    }
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      _downAt = event.position;
      _downPointer = event.pointer;
      return;
    }
    if (event.pointer != _downPointer) return;
    if (event is PointerCancelEvent) {
      _downAt = null;
      return;
    }
    if (event is! PointerUpEvent) return;
    final down = _downAt;
    _downAt = null;
    // A drag (a scroll) leaves it big.
    if (down == null || (event.position - down).distance > kTouchSlop) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final card = box.localToGlobal(Offset.zero) & box.size;
      // The card's own taps are its own (another one on its photo shrinks
      // it).
      if (card.contains(down)) return;
    }
    _shrink();
  }

  void _onLikeTap() {
    // The heart pops for a like on the grown card, not for taking one back.
    if (_big && !widget.isLiked) _heart.loop(count: 1);
    widget.onLikeTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: FutureBuilder<TravelMap?>(
        future: _map,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const ColoredBox(color: FeedPostGlobe._ground);
          }
          final map = snapshot.data;
          final pin = _drawnPin(map);
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final place = _PinCardPlace.of(
                size: size,
                pin: pin,
                camera: _camera,
              );
              if (pin != null) _camera ??= place.camera;
              // Grown: across the globe, in its middle (as high as fits).
              final width = math.max(
                place.card.width,
                math.min(
                  size.width - 2 * _grownMargin,
                  size.height - 2 * _grownMargin - _PostPinCard.bigFooterHeight,
                ),
              );
              final grown = Rect.fromCenter(
                center: size.center(Offset.zero),
                width: width,
                height: width + _PostPinCard.bigFooterHeight,
              );
              final spot = switch (map?.pinOf(widget.block.id)) {
                final pin? => (lat: pin.lat, lng: pin.lng),
                null => null,
              };
              return Stack(
                children: [
                  Positioned.fill(
                    child: GlobeView(
                      // Built once its data is in, so it opens on the post.
                      key: ValueKey('${widget.block.id}:${map != null}'),
                      controller: _globe,
                      visitedCounts: map?.regions ?? const {},
                      points: _points,
                      viewerId: context.read<AppBloc>().state.user.id,
                      initialCenter: _camera,
                      // No pin for the post (none fetched): their travels,
                      // as on their profile.
                      faceTravels: pin == null,
                      // +, − and back to the post's place, as on the profile
                      // (in its bottom right corner).
                      borderRadius: 0,
                    ),
                  ),
                  // The card on the pin, wherever the globe takes it. Only
                  // the card takes touches here; the rest is the globe's.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_growCurve, _globe.frames]),
                      builder: (context, _) => _cardOver(
                        place: place,
                        grown: grown,
                        at: spot == null || !_globe.isLaidOut
                            ? null
                            : _globe.pinAt(spot),
                        hasPin: spot != null,
                      ),
                    ),
                  ),
                  // How far they have travelled, as on their profile: over
                  // the card when the globe takes it under (it takes no
                  // touches, so the card under it still does).
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: TravelCountBadge(visited: map?.regions ?? const {}),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// The card and its arrow: on the pin drawn [at] (none while it is round
  /// the back), or at its place without a pin; [grown] as it grows.
  Widget _cardOver({
    required _PinCardPlace place,
    required Rect grown,
    required Offset? at,
    required bool hasPin,
  }) {
    final t = _growCurve.value;
    final onPin = at != null
        ? _PinCardPlace.over(at, place.card.size)
        // Not laid out yet: where it opens (as the globe will draw the pin).
        : hasPin && !_globe.isLaidOut && place.arrow != null
        ? (card: place.card, arrow: place.arrow!)
        : null;
    final small = onPin?.card ?? (hasPin ? null : place.card);
    return Stack(
      children: [
        if (onPin?.arrow case final arrow? when t < 1)
          Positioned.fromRect(
            rect: arrow,
            // Gone while the card is grown off the pin.
            child: Opacity(
              opacity: 1 - t.clamp(0.0, 1.0),
              // The grey of the card's buttons' row it hangs from.
              child: const CustomPaint(
                painter: _ArrowPainter(_PostPinCard.footerColor),
              ),
            ),
          ),
        if (small != null || t > 0)
          Positioned.fromRect(
            rect: small == null ? grown : Rect.lerp(small, grown, t)!,
            child: Opacity(
              // Grown with its pin round the back: it fades as it shrinks.
              opacity: small == null ? t.clamp(0.0, 1.0) : 1,
              child: _PostPinCard(
                key: _cardKey,
                block: widget.block,
                isLiked: widget.isLiked,
                isBookmarked: widget.isBookmarked,
                likesCount: widget.likesCount,
                commentsCount: widget.commentsCount,
                grown: t,
                big: _big,
                // Only the grown card's like pops a heart.
                heart: _big ? _heart : null,
                // The video plays once grown, as on the long-press card.
                playVideo: _big && _grow.isCompleted,
                onPhotoTap: _toggle,
                onLikeTap: _onLikeTap,
                onShareTap: widget.onShareTap,
                onCommentsTap: widget.onCommentsTap,
                onSaveTap: widget.onSaveTap,
              ),
            ),
          ),
      ],
    );
  }

  /// The grown card's margin to the globe's edges.
  static const double _grownMargin = AppSpacing.md;
}

/// Where the small card goes on a globe: over the post's pin, its arrow on
/// the pin, its top a little way down the box (below the travel count). The
/// globe turns so the pin sits a little above the middle (up to 20°) for it,
/// or a little below on a narrow phone: the card then covers less of the
/// globe while the post's place stays in view.
class _PinCardPlace {
  const _PinCardPlace({required this.card, this.arrow, this.camera});

  factory _PinCardPlace.of({
    required Size size,
    required ({double lat, double lng})? pin,
    required ({double lat, double lng})? camera,
  }) {
    final width = (size.width * 0.34).clamp(96.0, 150.0);
    final height = width + _PostPinCard.footerHeight;
    final r = GlobeView.wholeGlobeRadius(size);
    final c = size.center(Offset.zero);
    // The card's top a little way down the box, clear of the travel count.
    final top = math.max(_clearOfCount, size.height * _topShare);
    if (pin == null || r <= 0) {
      // No pin to stand on: the card where it would stand.
      return _PinCardPlace(
        card: Rect.fromLTWH((size.width - width) / 2, top, width, height),
      );
    }
    // The card's bottom over the pin's icon, the arrow between them.
    const under = GlobeView.pinIconTop + _gap + _arrowHeight;
    var turned = camera;
    if (turned == null) {
      final rise = ((c.dy - top - height - under) / r).clamp(
        -math.sin(15 * _deg),
        math.sin(20 * _deg),
      );
      turned = (
        lat: (pin.lat - math.asin(rise) / _deg).clamp(-85.0, 85.0),
        lng: pin.lng,
      );
    }
    // Orthographic, as the globe draws it (north up).
    final p0 = turned.lat * _deg;
    final p = pin.lat * _deg;
    final dl = (pin.lng - turned.lng) * _deg;
    final x = c.dx + r * math.cos(p) * math.sin(dl);
    final y =
        c.dy -
        r *
            (math.cos(p0) * math.sin(p) -
                math.sin(p0) * math.cos(p) * math.cos(dl));
    final left = (x - width / 2)
        .clamp(_margin, math.max(_margin, size.width - width - _margin))
        .toDouble();
    final arrowTop = y - under;
    return _PinCardPlace(
      card: Rect.fromLTWH(left, arrowTop - height, width, height),
      arrow: Rect.fromLTWH(
        x - _arrowWidth / 2,
        arrowTop - 0.5,
        _arrowWidth,
        _arrowHeight + 0.5,
      ),
      camera: turned,
    );
  }

  /// A [card]-sized card standing on the pin drawn [at] (the globe turned
  /// since it opened), its arrow on the pin.
  static ({Rect card, Rect arrow}) over(Offset at, Size card) {
    const under = GlobeView.pinIconTop + _gap + _arrowHeight;
    final arrowTop = at.dy - under;
    return (
      card: Rect.fromLTWH(
        at.dx - card.width / 2,
        arrowTop - card.height,
        card.width,
        card.height,
      ),
      arrow: Rect.fromLTWH(
        at.dx - _arrowWidth / 2,
        arrowTop - 0.5,
        _arrowWidth,
        _arrowHeight + 0.5,
      ),
    );
  }

  static const double _margin = 8;

  /// How far down the box the card's top goes (a share of its height), when
  /// the pin can be raised enough for it.
  static const double _topShare = 0.08;

  /// The card's top at least this far down: below the travel count in the
  /// corner.
  static const double _clearOfCount = 44;
  static const double _gap = 2;
  static const double _arrowWidth = 14;
  static const double _arrowHeight = 7;
  static const double _deg = math.pi / 180;

  final Rect card;

  /// The arrow under the card, its tip just over the pin's icon.
  final Rect? arrow;

  /// Where the globe is turned to.
  final ({double lat, double lng})? camera;
}

/// The post, small: its first photo (a video's first frame) and the feed
/// card's buttons — like and comment with their counts, share, save — as on
/// the profile grid's long-press card. [grown] takes it to that card's
/// proportions (0 on the pin, 1 across the globe): bigger buttons, and, once
/// [big], the full photo and the video playing.
class _PostPinCard extends StatelessWidget {
  const _PostPinCard({
    required this.block,
    required this.isLiked,
    required this.isBookmarked,
    required this.likesCount,
    required this.commentsCount,
    this.grown = 0,
    this.big = false,
    this.heart,
    this.playVideo = false,
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

  /// The popping heart of a like.
  final AnimationController? heart;
  final bool playVideo;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onSaveTap;

  static const double footerHeight = 34;

  /// Behind the buttons: the grey of the feed switch's pill.
  static const Color footerColor = AppColors.inputSpace;

  /// The grown card's buttons' row (the long-press card's).
  static const double bigFooterHeight = 52;

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
    final radius = BorderRadius.circular(lerpDouble(12, 16, t)!);
    final icon = lerpDouble(18, 28, t)!;
    final countSize = lerpDouble(12, 15, t)!;
    final video = block.firstMedia is VideoMedia;
    return DecoratedBox(
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
                        blurHash: block.firstMedia?.blurHash,
                      )
                    else
                      BlurHashImageThumbnail(
                        id: block.id,
                        decodeWidth: 480,
                        url: block.firstMediaThumbUrl ?? '',
                        blurHash: block.firstMedia?.blurHash,
                      ),
                    if (big && video && playVideo)
                      InlineVideo(
                        videoSettings: VideoSettings.build(
                          videoUrl: block.firstMedia?.url ?? '',
                          blurHash: block.firstMedia?.blurHash,
                          aspectRatio: 1,
                          withPlayerController: false,
                          shouldPlay: true,
                        ),
                      ),
                    if (heart case final heart?)
                      LikeAnimatedIcon(controller: heart),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: lerpDouble(footerHeight, bigFooterHeight, t),
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
          ],
        ),
      ),
    );
  }
}

/// The small card's arrow, pointing down at the pin.
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

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
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/feed/post/bloc/post_bloc.dart';
import 'package:treepnet/feed/post/widgets/post_popup_dialog.dart'
    show LikeAnimatedIcon;
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/map/view/location_posts_page.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart'
    show TravelCountBadge;
import 'package:user_repository/user_repository.dart';

/// Marks the new feed and Trends' Maps tab (prototypes): their posts show
/// their author's globe in place of the photos ([FeedPostGlobe]). Posts
/// anywhere else are as ever.
class FeedGlobeMode extends InheritedWidget {
  const FeedGlobeMode({
    required super.child,
    this.showPlace = true,
    this.showCaption = true,
    this.photosOnPins = false,
    super.key,
  });

  /// Trends' Maps tab: every post of the author as its small photo on its
  /// pin, any of them growing with its own buttons. Otherwise (the new feed)
  /// this post alone, as its small card — photo, buttons, an arrow to its
  /// pin. On both, the globe's pins open the author's posts there.
  final bool photosOnPins;

  /// The post's country and city (the new feed's): on its globe, in the
  /// bottom left corner, level with the globe's back-to-the-post button.
  /// Trends' Maps tab has none.
  final bool showPlace;

  /// The post's description (the new feed's): up beside the arrows under
  /// the globe, its time under it. Trends' Maps tab has neither.
  final bool showCaption;

  /// The mode [context] is in, if any.
  static FeedGlobeMode? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FeedGlobeMode>();

  /// Whether [context] is inside the new feed or Trends' Maps tab.
  static bool of(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(FeedGlobeMode oldWidget) =>
      showPlace != oldWidget.showPlace ||
      showCaption != oldWidget.showCaption ||
      photosOnPins != oldWidget.photosOnPins;
}

/// A post's author's travel globe, 4:5, in place of the post's photos (the
/// new feed): the whole globe as on their profile, turned to the post's
/// place, with how far they have travelled in its top left corner and a
/// small card of the post (as the profile grid's long-press one) standing
/// over its pin, the author's other posts' on theirs. A tap on a photo — this
/// post's or another's — grows it, in its place, to the globe's width with
/// that post's buttons under it (like, share, comment, save); another tap on
/// it, a tap anywhere else, or a scroll of the feed shrinks it back. Nothing
/// else changes meanwhile: no dimming. The globe turns and zooms as on the
/// profile, its +, − and back-to-the-post buttons over the photos, which go
/// round with their pins (gone round the back); the new feed scrolls by its
/// arrows only, so a drag is always the globe's.
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

  /// This post's like and save (another post grown on the globe has its
  /// own, see [_OtherPost]).
  final VoidCallback? onLikeTap;
  final VoidCallback? onSaveTap;

  /// Share and comments, for the post grown: this one, or another of the
  /// author's.
  final ValueSetter<PostBlock>? onShareTap;
  final ValueSetter<PostBlock>? onCommentsTap;

  /// The globe's ground (as [GlobeView] paints it), while it loads.
  static const _ground = Color(0xFF15181B);

  /// The globe's +, − and back buttons' margin to its right and bottom
  /// edges (the arrows under the post line up under them, FeedPostSteps).
  static const double buttonsInset = 8;

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

  /// The author's other posts with a photo, one per spot, newest first: shown
  /// on their pins at the same time as this one.
  List<TravelPin> _others = const [];

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

  /// The post grown, growing or shrinking back: this one, or another of the
  /// author's ([_other]); null while none is.
  String? _shownId;

  /// Another of the author's posts grown from its photo on its pin.
  _OtherPost? _other;

  /// The small photos as last drawn (in the globe's box, the topmost last):
  /// a tap on one grows it. They take no touches themselves, so a drag over
  /// one turns the globe; a [Listener] over them tells the taps.
  List<(String, Rect)> _photoHits = const [];
  Offset? _tapDown;
  int? _tapPointer;

  /// When a tap last went to a photo or a grown card (opened, shrunk): the
  /// globe hears the same tap a moment later (after its double-tap window)
  /// and must not take it for one on a pin.
  DateTime? _tapUsedAt;

  void _useTap() => _tapUsedAt = DateTime.now();

  /// Long enough to cover the globe's double-tap wait.
  static const _tapWindow = Duration(milliseconds: 700);

  /// A tap on a pin (or, merged, on its region's), as on the author's
  /// profile: their posts there.
  void _openPlace(TravelMapTarget target) {
    final used = _tapUsedAt;
    if (_big ||
        (used != null && DateTime.now().difference(used) < _tapWindow)) {
      return;
    }
    final lang = Localizations.localeOf(context).languageCode;
    LocationPostsPage.push(
      context,
      userId: widget.block.author.id,
      regionIso: target.region.iso,
      regionName: target.region.localizedDisplayName(lang),
      // The author's own name for the spot; their words, as on the profile.
      placeName: target.point?.name,
      countryName: target.region.localizedCountryName(lang),
      scope: target.point == null
          ? LocationPostsScope.region
          : LocationPostsScope.point,
      lat: target.point?.lat,
      lng: target.point?.lng,
    );
  }

  void _onTapDown(PointerDownEvent event) {
    _tapDown = event.localPosition;
    _tapPointer = event.pointer;
  }

  void _onTapUp(PointerUpEvent event) {
    if (event.pointer != _tapPointer) return;
    final down = _tapDown;
    _tapDown = null;
    // A drag turns the globe; while one is grown, a tap off it shrinks it
    // (see [_onPointer]).
    if (down == null ||
        (event.localPosition - down).distance > kTouchSlop ||
        _big) {
      return;
    }
    for (final (id, rect) in _photoHits.reversed) {
      if (!rect.contains(down)) continue;
      _useTap();
      if (id == widget.block.id) {
        _expand();
      } else {
        for (final pin in _others) {
          if (pin.postId == id) return _openOther(pin);
        }
      }
      return;
    }
  }

  /// Where a finger went down while the card is big, to shrink it if that
  /// is a tap off the card (not a scroll).
  Offset? _downAt;
  int? _downPointer;

  Future<TravelMap?> _fetch() async {
    final map = await context.read<PostsRepository>().travelMapOf(
      userId: widget.block.author.id,
    );
    _points = map?.points ?? const [];
    final spots = <String>{};
    _others = [
      for (final pin in map?.pins ?? const <TravelPin>[])
        if (pin.postId != null &&
            pin.postId != widget.block.id &&
            pin.thumb != null &&
            spots.add(GlobeController.pinKeyOf((lat: pin.lat, lng: pin.lng))))
          pin,
    ];
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
    _grow.addStatusListener((status) {
      // Shrunk back onto its pin: no post shown big any more.
      if (status != AnimationStatus.dismissed || !mounted) return;
      setState(() {
        _shownId = null;
        _closeOther();
      });
    });
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
    _closeOther();
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

  /// Grows this post, or [other] (another of the author's).
  void _expand({_OtherPost? other}) {
    if (_big) return;
    setState(() {
      _big = true;
      if (!identical(_other, other)) _closeOther();
      _other = other;
      _shownId = other?.pin.postId ?? widget.block.id;
    });
    _listenForTapsOff(true);
    _listenForScroll(true);
    unawaited(_grow.forward());
  }

  /// Grows another of the author's posts from its photo on [pin]: at once
  /// with the photo the pin has, the post itself (its full photo, its
  /// counts, its like and save) as it comes in.
  void _openOther(TravelPin pin) {
    final id = pin.postId;
    if (_big || id == null) return;
    final bloc =
        PostBloc(
          postId: id,
          postsRepository: context.read<PostsRepository>(),
          userRepository: context.read<UserRepository>(),
        )..add(
          PostStatsSubscriptionRequested(
            ownerId: widget.block.author.id,
            currentUserId: context.read<AppBloc>().state.user.id,
          ),
        );
    final other = _OtherPost(
      pin: pin,
      bloc: bloc,
      block: PostLargeBlock(
        id: id,
        author: widget.block.author,
        createdAt: widget.block.createdAt,
        media: [ImageMedia(id: id, url: pin.thumb ?? '', thumbUrl: pin.thumb)],
        caption: '',
      ),
    );
    _expand(other: other);
    unawaited(
      context.read<PostsRepository>().getPostBy(id: id).then((post) {
        if (!mounted || !identical(_other, other) || post == null) return;
        setState(() {
          other
            ..block = post.toPostLargeBlock
            ..loaded = true;
        });
      }, onError: (Object _) {}),
    );
  }

  void _closeOther() {
    unawaited(_other?.bloc.close());
    _other = null;
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
    // On the card or off it, the tap is the card's, not the globe's.
    _useTap();
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

  /// Trends' style ([FeedGlobeMode.photosOnPins]), or the new feed's card.
  bool get _photos => FeedGlobeMode.maybeOf(context)?.photosOnPins ?? false;

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final showPlace = FeedGlobeMode.maybeOf(context)?.showPlace ?? true;
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
                photo: photos,
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
                      // A pin tapped opens the author's posts there, as on
                      // their profile (the new feed and Trends alike).
                      onTargetTap: _openPlace,
                      // Trends draws its +, − and back-to-the-post buttons
                      // over the photos (below); the new feed has the
                      // globe's own.
                      showButtons: !photos,
                      borderRadius: 0,
                    ),
                  ),
                  // Its country and city, in the bottom left corner, level
                  // with the globe's back-to-the-post button (the lowest of
                  // its three) and clear of them. A label: touches go to
                  // the globe; the card can go over it.
                  if (showPlace)
                    Positioned(
                      left: FeedPostGlobe.buttonsInset,
                      right: FeedPostGlobe.buttonsInset * 2 + GlobeButtons.size,
                      bottom: FeedPostGlobe.buttonsInset,
                      height: GlobeButtons.size,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FeedPostPlace(
                            block: widget.block,
                            onGlobe: true,
                          ),
                        ),
                      ),
                    ),
                  // The posts' photos on their pins, wherever the globe takes
                  // them. Only this post's takes touches here; the rest is
                  // the globe's.
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_growCurve, _globe.frames]),
                      builder: (context, _) => _photosOver(
                        place: place,
                        grown: grown,
                        spot: spot,
                        photos: photos,
                      ),
                    ),
                  ),
                  // Taps on the small photos (see [_photoHits]): heard, not
                  // taken, so the globe still turns under a drag.
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _onTapDown,
                      onPointerUp: _onTapUp,
                      onPointerCancel: (_) => _tapDown = null,
                    ),
                  ),
                  // +, − and back to the post's place, as on the profile, in
                  // the bottom right corner — over the photos the globe
                  // takes under them; gone while a post is grown there.
                  if (photos)
                    Positioned(
                      right: FeedPostGlobe.buttonsInset,
                      bottom: FeedPostGlobe.buttonsInset,
                      child: AnimatedBuilder(
                        animation: _growCurve,
                        builder: (context, child) {
                          final t = _growCurve.value.clamp(0.0, 1.0);
                          return IgnorePointer(
                            ignoring: t > 0,
                            child: Opacity(opacity: 1 - t, child: child),
                          );
                        },
                        child: GlobeButtons(controller: _globe),
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

  /// The posts' photos on their pins: this post's on [spot] (where it opens
  /// until the globe is laid out; growing to [grown]), and the author's
  /// other posts' around it — one per pin as drawn (a region's merge while
  /// zoomed out), the newest, none over another, none round the back.
  Widget _photosOver({
    required _PinCardPlace place,
    required Rect grown,
    required ({double lat, double lng})? spot,
    required bool photos,
  }) {
    final t = _growCurve.value;
    final size = place.card.size;
    final laidOut = _globe.isLaidOut;
    final drawn = laidOut
        ? _globe.pinsAt([
            ?spot,
            if (photos)
              for (final pin in _others) (lat: pin.lat, lng: pin.lng),
          ])
        : const <String, Offset>{};
    final at = spot == null ? null : drawn[GlobeController.pinKeyOf(spot)];
    final Rect? small;
    // The new feed's card hangs from an arrow on its pin.
    Rect? arrow;
    if (spot == null || !laidOut) {
      // No pin, or not laid out yet: where it opens.
      small = place.card;
      if (spot != null) arrow = place.arrow;
    } else if (at == null) {
      small = null;
    } else {
      final onPin = _PinCardPlace.over(at, size, withArrow: !photos);
      small = onPin.card;
      arrow = onPin.arrow;
    }

    // The post grown, growing or shrinking: where it grows from.
    final shownOther = _other;
    final otherSmall = shownOther == null
        ? null
        : switch (drawn[GlobeController.pinKeyOf((
            lat: shownOther.pin.lat,
            lng: shownOther.pin.lng,
          ))]) {
            final where? => _PinCardPlace.over(where, size).card,
            null => null,
          };

    // The others (Trends only), the newest first; one where another already
    // is goes.
    final taken = <Rect>[?small];
    final others = <(TravelPin, Rect)>[];
    for (final pin in photos ? _others : const <TravelPin>[]) {
      if (others.length >= _maxOthers) break;
      // Grown from its pin: drawn big below, not small here.
      if (pin.postId == _shownId) continue;
      final where =
          drawn[GlobeController.pinKeyOf((lat: pin.lat, lng: pin.lng))];
      if (where == null) continue;
      final rect = _PinCardPlace.over(where, size).card;
      if (taken.any((other) => _covers(other, rect))) continue;
      taken.add(rect);
      others.add((pin, rect));
    }

    final thisShown = _shownId == widget.block.id;
    // Trends' photos take no touches (a drag over one turns the globe; the
    // listener over them tells their taps); the new feed's card takes its
    // own (its buttons, its photo).
    _photoHits = [
      if (photos) ...[
        for (final (pin, rect) in others) (pin.postId!, rect),
        if (!thisShown && small != null) (widget.block.id, small),
      ],
    ];
    Widget thisCard({required double grown}) => _PostPinCard(
      key: thisShown || !photos ? _cardKey : null,
      block: widget.block,
      photoOnly: photos,
      isLiked: widget.isLiked,
      isBookmarked: widget.isBookmarked,
      likesCount: widget.likesCount,
      commentsCount: widget.commentsCount,
      grown: grown,
      big: thisShown && _big,
      // Only the grown card's like pops a heart.
      heart: thisShown && _big ? _heart : null,
      // The video plays once grown, as on the long-press card.
      playVideo: thisShown && _big && _grow.isCompleted,
      onPhotoTap: _toggle,
      onLikeTap: _onLikeTap,
      onShareTap: () => widget.onShareTap?.call(widget.block),
      onCommentsTap: () => widget.onCommentsTap?.call(widget.block),
      onSaveTap: widget.onSaveTap,
    );

    return Stack(
      children: [
        for (final (pin, rect) in others)
          Positioned.fromRect(
            key: ValueKey('other:${pin.postId}'),
            rect: rect,
            child: _OtherPhoto(url: pin.thumb!),
          ),
        // The new feed's card hangs from its arrow, gone as it grows.
        if (arrow != null && t < 1 && (thisShown || !_big))
          Positioned.fromRect(
            rect: arrow,
            child: Opacity(
              opacity: 1 - t.clamp(0.0, 1.0),
              // The grey of the card's buttons' row it hangs from.
              child: const CustomPaint(
                painter: _ArrowPainter(_PostPinCard.footerColor),
              ),
            ),
          ),
        // This post on its pin, unless it is the one grown. On Trends a
        // picture, as the others (its taps are told by the listener over
        // them); on the new feed its card, taking its own taps.
        if (!thisShown && small != null)
          Positioned.fromRect(
            rect: small,
            child: photos
                ? IgnorePointer(child: thisCard(grown: 0))
                : thisCard(grown: 0),
          ),
        // The post grown, growing or shrinking back onto its pin.
        if (thisShown && (small != null || t > 0))
          Positioned.fromRect(
            rect: small == null ? grown : Rect.lerp(small, grown, t)!,
            child: Opacity(
              // Grown with its pin round the back: it fades as it shrinks.
              opacity: small == null ? t.clamp(0.0, 1.0) : 1,
              child: thisCard(grown: t),
            ),
          ),
        if (shownOther != null && (otherSmall != null || t > 0))
          Positioned.fromRect(
            rect: otherSmall == null ? grown : Rect.lerp(otherSmall, grown, t)!,
            child: Opacity(
              opacity: otherSmall == null ? t.clamp(0.0, 1.0) : 1,
              child: _OtherCard(
                key: _cardKey,
                other: shownOther,
                grown: t,
                big: _big,
                heart: _big ? _heart : null,
                playVideo: _big && _grow.isCompleted,
                onPhotoTap: _toggle,
                onShareTap: widget.onShareTap,
                onCommentsTap: widget.onCommentsTap,
              ),
            ),
          ),
      ],
    );
  }

  /// Whether [a] would hide much of [b] (over a third of it).
  static bool _covers(Rect a, Rect b) {
    final overlap = a.intersect(b);
    if (overlap.width <= 0 || overlap.height <= 0) return false;
    return overlap.width * overlap.height > b.width * b.height / 3;
  }

  /// At most this many other photos at once (a city zoomed into can have
  /// dozens of posts).
  static const _maxOthers = 40;

  /// The grown card's margin to the globe's edges.
  static const double _grownMargin = AppSpacing.md;
}

/// Where the post goes on a globe, on its pin. On Trends (`photo`) its small
/// photo, standing on the pin, the globe turned to put the pin in its
/// middle. On the new feed its card, over an arrow to the pin, its top a
/// little way down the box (below the travel count): the globe turns so the
/// pin sits a little above the middle (up to 20°) for it, or a little below
/// on a narrow phone — the card then covers less of the globe while the
/// post's place stays in view.
class _PinCardPlace {
  const _PinCardPlace({required this.card, this.arrow, this.camera});

  factory _PinCardPlace.of({
    required Size size,
    required ({double lat, double lng})? pin,
    required ({double lat, double lng})? camera,
    required bool photo,
  }) {
    final r = GlobeView.wholeGlobeRadius(size);
    final c = size.center(Offset.zero);
    if (photo) {
      final side = photoSide(size);
      if (pin == null || r <= 0) {
        // No pin to stand on: the photo a little way down the middle.
        return _PinCardPlace(
          card: Rect.fromLTWH((size.width - side) / 2, _noPinTop, side, side),
        );
      }
      // Facing the pin: drawn in the middle (until the globe turns).
      return _PinCardPlace(
        card: over(c, Size.square(side)).card,
        camera: camera ?? (lat: pin.lat.clamp(-85.0, 85.0), lng: pin.lng),
      );
    }

    final width = (size.width * 0.34).clamp(96.0, 150.0);
    final height = width + _PostPinCard.footerHeight;
    // The card's top a little way down the box, clear of the travel count.
    final top = math.max(_noPinTop, size.height * _topShare);
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
    final at = Offset(
      c.dx + r * math.cos(p) * math.sin(dl),
      c.dy -
          r *
              (math.cos(p0) * math.sin(p) -
                  math.sin(p0) * math.cos(p) * math.cos(dl)),
    );
    final onPin = over(at, Size(width, height), withArrow: true);
    final left = onPin.card.left
        .clamp(_margin, math.max(_margin, size.width - width - _margin))
        .toDouble();
    return _PinCardPlace(
      card: onPin.card.translate(left - onPin.card.left, 0),
      arrow: onPin.arrow,
      camera: turned,
    );
  }

  /// A photo's side on a [box] globe (Trends): small, a sixth of its width
  /// or so.
  static double photoSide(Size box) => (box.width * 0.17).clamp(52.0, 76.0);

  /// A [size]d photo or card standing on the pin drawn [at]: its bottom just
  /// over the pin's icon — or, [withArrow] (the new feed's card), over an
  /// arrow down to it.
  static ({Rect card, Rect? arrow}) over(
    Offset at,
    Size size, {
    bool withArrow = false,
  }) {
    final under = GlobeView.pinIconTop + _gap + (withArrow ? _arrowHeight : 0);
    final bottom = at.dy - under;
    return (
      card: Rect.fromLTWH(
        at.dx - size.width / 2,
        bottom - size.height,
        size.width,
        size.height,
      ),
      arrow: withArrow
          ? Rect.fromLTWH(
              at.dx - _arrowWidth / 2,
              bottom - 0.5,
              _arrowWidth,
              _arrowHeight + 0.5,
            )
          : null,
    );
  }

  static const double _margin = 8;

  /// How far down the box the new feed's card's top goes (a share of its
  /// height), when the pin can be raised enough for it.
  static const double _topShare = 0.08;

  /// The top at least this far down: below the travel count in the corner.
  static const double _noPinTop = 44;
  static const double _gap = 2;
  static const double _arrowWidth = 14;
  static const double _arrowHeight = 7;
  static const double _deg = math.pi / 180;

  final Rect card;

  /// The new feed's card's arrow, its tip just over the pin's icon.
  final Rect? arrow;

  /// Where the globe is turned to.
  final ({double lat, double lng})? camera;
}

/// The post on its pin: on Trends ([photoOnly]) its first photo alone (a
/// video's first frame), small, white-edged; on the new feed its card — the
/// photo and the feed card's buttons under it (like and comment with their
/// counts, share, save) on the switch's grey. [grown] (0 on the pin, 1
/// across the globe) takes it to the profile grid's long-press card's size,
/// the buttons coming in under a lone photo; once [big], the full photo and
/// the video playing.
class _PostPinCard extends StatelessWidget {
  const _PostPinCard({
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
  final bool playVideo;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onLikeTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onSaveTap;

  /// The new feed's small card's buttons' row.
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
    final radius = BorderRadius.circular(
      lerpDouble(photoOnly ? 10 : 12, 16, t)!,
    );
    final footer = lerpDouble(
      photoOnly ? 0 : footerHeight,
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
                          blurHash: block.firstMedia?.blurHash,
                        )
                      else
                        BlurHashImageThumbnail(
                          id: block.id,
                          decodeWidth: photoOnly ? 240 : 480,
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

/// Another of the author's posts grown from its photo on its pin.
class _OtherPost {
  _OtherPost({required this.pin, required this.bloc, required this.block});

  final TravelPin pin;

  /// Its own likes, save and counts (the feed card's bloc is this post's).
  final PostBloc bloc;

  /// The post: a stand-in made from the pin (its photo) until it is in.
  PostBlock block;
  bool loaded = false;
}

/// [_OtherPost] grown: the same card as the post's own, with its own like,
/// save and counts; its comments and share once the post is in.
class _OtherCard extends StatelessWidget {
  const _OtherCard({
    required this.other,
    required this.grown,
    required this.big,
    required this.playVideo,
    this.heart,
    this.onPhotoTap,
    this.onShareTap,
    this.onCommentsTap,
    super.key,
  });

  final _OtherPost other;
  final double grown;
  final bool big;
  final bool playVideo;
  final AnimationController? heart;
  final VoidCallback? onPhotoTap;
  final ValueSetter<PostBlock>? onShareTap;
  final ValueSetter<PostBlock>? onCommentsTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostBloc, PostState>(
      bloc: other.bloc,
      builder: (context, state) => _PostPinCard(
        block: other.block,
        photoOnly: true,
        isLiked: state.isLiked,
        isBookmarked: state.isBookmarked,
        likesCount: state.likes,
        commentsCount: state.commentsCount,
        grown: grown,
        big: big,
        heart: heart,
        playVideo: playVideo && other.loaded,
        onPhotoTap: onPhotoTap,
        onLikeTap: () {
          // The heart pops for a like, not for taking one back.
          if (!state.isLiked) heart?.loop(count: 1);
          other.bloc.add(const PostLikeRequested());
        },
        onSaveTap: () => other.bloc.add(const PostBookmarkRequested()),
        onShareTap: other.loaded ? () => onShareTap?.call(other.block) : null,
        onCommentsTap: other.loaded
            ? () => onCommentsTap?.call(other.block)
            : null,
      ),
    );
  }
}

/// Another of the author's posts on its pin: its small photo, white-edged
/// (more faintly than the post's own). A picture: a drag over it turns the
/// globe, a tap grows it (told by the listener over the photos).
class _OtherPhoto extends StatelessWidget {
  const _OtherPhoto({required this.url});

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
            color: _PostPinCard.footerColor,
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

/// The new feed's small card's arrow, pointing down at the pin.
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

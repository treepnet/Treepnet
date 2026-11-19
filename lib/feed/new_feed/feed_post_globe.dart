import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart' hide NumDurationExtension;
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/new_feed/feed_globe_mode.dart';
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/feed/new_feed/feed_post_steps.dart';
import 'package:treepnet/feed/new_feed/pin_card_place.dart';
import 'package:treepnet/feed/new_feed/post_pin_card.dart';
import 'package:treepnet/feed/post/bloc/post_bloc.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
import 'package:treepnet/map/view/location_posts_page.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart'
    show TravelCountBadge;
import 'package:user_repository/user_repository.dart';

export 'package:treepnet/feed/new_feed/feed_globe_mode.dart';

/// A post's author's travel globe, 4:5, in place of the post's photos (the
/// new feed, Trends' Maps tab — see [FeedGlobeMode]): the whole globe as on
/// their profile, turned to the post's place, with how far they have
/// travelled in its top left corner.
///
/// - The new feed ([FeedGlobeStyle.card]): the post's small card (as the
///   profile grid's long-press one) stands over its pin, its buttons
///   working; its country and city in the bottom left corner.
/// - Trends ([FeedGlobeStyle.photos]): every post of the author as its
///   small photo on its pin.
///
/// A tap on a post's photo grows it, in its place, to the globe's width with
/// that post's buttons under it (like, share, comment, save); another tap on
/// it, a tap anywhere else, or a scroll of the list shrinks it back. Nothing
/// else changes meanwhile: no dimming. The globe turns and zooms as on the
/// profile; the cards and photos go round with their pins (gone round the
/// back); its pins open the author's posts there.
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
  static const double buttonsInset = GlobeButtons.inset;

  @override
  State<FeedPostGlobe> createState() => _FeedPostGlobeState();
}

class _FeedPostGlobeState extends State<FeedPostGlobe>
    with TickerProviderStateMixin {
  // --- the author's travel map ----------------------------------------------

  /// Fetched, or failed, once at least: the globe shows (bare, without one).
  bool _loaded = false;
  TravelMap? _map;

  /// Counts the maps shown: each builds the globe anew, opening on the post.
  int _shown = 0;

  /// The latest fetch: an older one's answer is dropped.
  int _fetches = 0;

  /// The next fetch, after a failed one or one without the post's pin.
  Timer? _again;
  int _tries = 0;

  /// The pins as the globe takes them: the map's own list each build (a new
  /// one would have the globe build its scene again).
  List<({double lat, double lng, String? name})> _points = const [];

  /// The post's spot, and the key the globe knows its pin by.
  ({double lat, double lng})? _spot;
  String? _spotKey;

  /// The author's other posts with a photo, one per spot, newest first
  /// (Trends shows them on their pins at the same time as this one).
  List<({TravelPin pin, String key})> _others = const [];

  /// The pins the photos follow, asked of the globe on each of its frames.
  Set<String> _followed = const {};

  /// Where the globe was turned to (its opening centre, kept: it reads it
  /// only once), set the first time it shows with the map.
  ({double lat, double lng})? _camera;

  /// Where the zoomed-out globe draws the post's pin (a region's pins merge
  /// into one, see [GlobeView.zoomedOutPinOf]): worked out again once the
  /// map data is in.
  ({double lat, double lng})? _drawnPin;
  bool _drawnWithRegions = false;

  /// Where the globe looks, and where it draws the pins.
  final _globe = GlobeController();

  /// Whether the list is on screen ([FeedGlobeMode.onScreen]).
  ValueListenable<bool>? _onScreen;

  /// Fingers on the globe. A map that comes in meanwhile (a retry, a fresh
  /// one) waits for them to lift: built anew under a finger, the globe would
  /// drop the gesture halfway.
  int _fingersOnGlobe = 0;
  ({TravelMap? map})? _waiting;

  // --- the card grown -------------------------------------------------------

  /// The card, to tell a tap on it from one elsewhere.
  final _cardKey = GlobalKey();

  /// 0 small, over the pin; 1 grown.
  late final AnimationController _grow;
  late final Animation<double> _growCurve;

  /// The grown card's heart, popping on a like (the long-press card's): one
  /// for each grow. The heart's animation leaves a listener on it that is
  /// never taken off: shared by every grow, those piled up.
  AnimationController? _heart;

  /// Grown, or growing.
  bool _big = false;

  /// The post grown, growing or shrinking back: this one, or another of the
  /// author's ([_other]); null while none is.
  String? _shownId;

  /// Another of the author's posts grown from its photo on its pin.
  _OtherPost? _other;

  /// Trends' small photos as last drawn (in the globe's box, the topmost
  /// last): a tap on one grows it. They take no touches themselves, so a
  /// drag over one turns the globe; a [Listener] over them tells the taps.
  List<(String, Rect)> _photoHits = const [];

  /// The fingers on the photos, and the one that may be tapping.
  final _fingers = <int>{};
  int? _tapPointer;
  Offset? _tapDown;

  /// Whether that finger went down on the card shown big: the card's own tap
  /// (decided as it goes down; a shrinking card moves away under it).
  bool _tapDownOnCard = false;

  /// The feed's list while the card is big, and where it stood then.
  ScrollPosition? _scroll;
  double _scrolledFrom = 0;

  /// Listening for taps anywhere on the screen (while the card is big).
  bool _listening = false;

  /// Where a finger went down while the card is big, to shrink it if that
  /// is a tap off the card (not a scroll), and whether it went down on it.
  Offset? _downAt;
  int? _downPointer;
  bool _downOnCard = false;

  bool get _photos => FeedGlobeMode.maybeOf(context)?.photosOnPins ?? false;

  bool get _isOnScreen => _onScreen?.value ?? true;

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    )..addStatusListener(_onGrowStatus);
    _growCurve = CurvedAnimation(
      parent: _grow,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    final geo = GeoRegions.instance;
    if (!geo.isLoaded) {
      // Once in, the post's pin merges with its region's: the card follows.
      unawaited(
        geo.load().then((_) {
          if (mounted) setState(() {});
        }, onError: (Object _) {}),
      );
    }
    unawaited(_fetch());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mode = FeedGlobeMode.maybeOf(context);
    final onScreen = mode?.onScreen;
    if (!identical(onScreen, _onScreen)) {
      _onScreen?.removeListener(_onScreenChanged);
      _onScreen = onScreen?..addListener(_onScreenChanged);
    }
    final above = mode?.aboveFirstPost;
    if (!identical(above, _aboveFirstPost)) {
      _aboveFirstPost?.removeListener(_measureAboveSoon);
      _aboveFirstPost = above?..addListener(_measureAboveSoon);
    }
  }

  @override
  void didUpdateWidget(covariant FeedPostGlobe oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another post in this place (lists key their posts, so only should
    // one not): everything of the old one goes.
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.author.id != widget.block.author.id) {
      _shrinkAtOnce();
      _again?.cancel();
      _tries = 0;
      _waiting = null;
      _loaded = false;
      _map = null;
      unawaited(_fetch());
    }
  }

  @override
  void dispose() {
    _again?.cancel();
    _onScreen?.removeListener(_onScreenChanged);
    _aboveFirstPost?.removeListener(_measureAboveSoon);
    _listenForTapsOff(false);
    _listenForScroll(false);
    _closeOther();
    _grow.dispose();
    _heart?.dispose();
    _globe.dispose();
    super.dispose();
  }

  // --- the map --------------------------------------------------------------

  /// Fetches the author's map ([fresh]: not the one kept from before) and
  /// shows it. A failed fetch is tried again a little later (the globe bare
  /// until then); so is one without this post's pin, while the post is new
  /// (the map kept from before it, or the post not uploaded yet).
  Future<void> _fetch({bool fresh = false}) async {
    final fetch = ++_fetches;
    final posts = context.read<PostsRepository>();
    final author = widget.block.author.id;
    TravelMap? map;
    var failed = false;
    try {
      map = await (fresh
          ? posts.travelMapOf(userId: author, fresh: true)
          : posts.travelMapOf(userId: author));
    } catch (_) {
      failed = true;
    }
    if (!mounted || fetch != _fetches) return;
    final missing =
        !failed && map != null && map.pinOf(widget.block.id) == null;
    if (failed) {
      // Nothing yet: the globe shows bare meanwhile. Shown already: it stays.
      if (!_loaded) setState(() => _show(null));
      _fetchAgainLater(fresh: fresh);
      return;
    }
    // A fresh map that still lacks the pin changes nothing on screen.
    if (!(fresh && missing)) _showOrWait(map);
    if (missing && _isNew) {
      _fetchAgainLater(fresh: true);
    } else {
      _tries = 0;
    }
  }

  /// Placed, and posted lately: its pin may not be in a map fetched before
  /// it, or before it was uploaded.
  bool get _isNew =>
      (widget.block.location?.trim().isNotEmpty ?? false) &&
      DateTime.now().difference(widget.block.createdAt) <
          const Duration(hours: 1);

  /// Waits between tries: the first again at once when asking for a map
  /// newer than the one kept, then longer and longer.
  static const _waits = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  void _fetchAgainLater({bool fresh = false}) {
    if (_tries >= _waits.length) return;
    final wait = fresh && _tries == 0 ? Duration.zero : _waits[_tries];
    _tries++;
    _again?.cancel();
    _again = Timer(wait, () {
      if (mounted) unawaited(_fetch(fresh: fresh));
    });
  }

  /// Shows [map] — once no finger is on the globe, if one is shown already.
  void _showOrWait(TravelMap? map) {
    if (_loaded && _fingersOnGlobe > 0) {
      _waiting = (map: map);
      return;
    }
    setState(() => _show(map));
  }

  void _onGlobeDown(PointerDownEvent _) => _fingersOnGlobe++;

  void _offGlobe(PointerEvent _) {
    _fingersOnGlobe = math.max(0, _fingersOnGlobe - 1);
    final waiting = _waiting;
    if (_fingersOnGlobe > 0 || waiting == null || !mounted) return;
    _waiting = null;
    setState(() => _show(waiting.map));
  }

  /// Takes [map] in (null: none to show).
  void _show(TravelMap? map) {
    _loaded = true;
    _map = map;
    _shown++;
    _points = map?.points ?? const [];
    final pin = map?.pinOf(widget.block.id);
    final spot = pin == null ? null : (lat: pin.lat, lng: pin.lng);
    _spot = spot;
    _spotKey = spot == null ? null : GlobeController.pinKeyOf(spot);
    _camera = null;
    _drawnPin = null;
    final spots = <String>{};
    _others = [
      if (_photos && map != null)
        for (final pin in map.pins)
          if (pin.postId case final id?
              when id != widget.block.id && pin.thumb != null)
            if (GlobeController.pinKeyOf((lat: pin.lat, lng: pin.lng))
                case final key when spots.add(key))
              (pin: pin, key: key),
    ];
    _followed = {?_spotKey, for (final other in _others) other.key};
  }

  /// Where the zoomed-out globe draws the post's pin, if it has one.
  ({double lat, double lng})? _drawnPinNow() {
    final spot = _spot;
    if (spot == null) return null;
    final withRegions = GeoRegions.instance.isLoaded;
    if (_drawnPin == null || withRegions != _drawnWithRegions) {
      _drawnPin = GlobeView.zoomedOutPinOf(_points, spot);
      _drawnWithRegions = withRegions;
    }
    return _drawnPin;
  }

  /// A tap on a pin (or, merged, on its region's), as on the author's
  /// profile: their posts there.
  void _openPlace(TravelMapTarget target) {
    if (_big) return;
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

  /// A tap the globe heard that was the photos' or the card's: one on a
  /// photo (it grows), or any while one is grown (it shrinks).
  bool _claimTap(Offset at) => _big || _photoAt(at) != null;

  // --- taps on Trends' photos -----------------------------------------------

  /// The topmost photo at [at] (in the globe's box), by its post's id.
  String? _photoAt(Offset at) {
    for (final (id, rect) in _photoHits.reversed) {
      if (rect.contains(at)) return id;
    }
    return null;
  }

  void _onPhotosDown(PointerDownEvent event) {
    _fingers.add(event.pointer);
    if (_fingers.length > 1) {
      // A second finger: a pinch, not a tap.
      _tapPointer = null;
      return;
    }
    _tapPointer = event.pointer;
    _tapDown = event.localPosition;
    _tapDownOnCard = _isOnCard(event.position);
  }

  void _onPhotosMove(PointerMoveEvent event) {
    final down = _tapDown;
    // A drag turns the globe.
    if (event.pointer == _tapPointer &&
        down != null &&
        (event.localPosition - down).distance > kTouchSlop) {
      _tapPointer = null;
    }
  }

  void _onPhotosUp(PointerUpEvent event) {
    _fingers.remove(event.pointer);
    if (event.pointer != _tapPointer) return;
    _tapPointer = null;
    final down = _tapDown;
    // While one is grown, a tap off it shrinks it ([_onPointer]); one on it
    // is its own — also while it shrinks (its photo grows it again).
    if (down == null || _big || _tapDownOnCard) return;
    final id = _photoAt(down);
    if (id == null) return;
    if (id == widget.block.id) return _expand();
    for (final other in _others) {
      if (other.pin.postId == id) return _openOther(other);
    }
  }

  void _onPhotosCancel(PointerCancelEvent event) {
    _fingers.remove(event.pointer);
    if (event.pointer == _tapPointer) _tapPointer = null;
  }

  /// Whether [onScreen] is on the card shown big (grown, growing or
  /// shrinking).
  bool _isOnCard(Offset onScreen) {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return false;
    return (box.localToGlobal(Offset.zero) & box.size).contains(onScreen);
  }

  // --- growing and shrinking ------------------------------------------------

  void _onGrowStatus(AnimationStatus status) {
    // Shrunk back onto its pin: no post shown big any more.
    if (status != AnimationStatus.dismissed || !mounted || _big) return;
    if (_shownId == null && _other == null) return;
    setState(() {
      _shownId = null;
      _closeOther();
    });
  }

  /// A tap on this post's photo: on its pin it grows; grown, it shrinks;
  /// shrinking, it grows again.
  void _onPhotoTap() =>
      _big && _shownId == widget.block.id ? _shrink() : _expand();

  /// Grows this post, or [other] (another of the author's).
  void _expand({_OtherPost? other}) {
    if (_big) return;
    final id = other?.pin.postId ?? widget.block.id;
    // Another one still shrinking goes back onto its pin at once; this one
    // grows from its own.
    if (_shownId != null && _shownId != id) _grow.value = 0;
    setState(() {
      _big = true;
      if (!identical(_other, other)) _closeOther();
      _other = other;
      _shownId = id;
      // A new heart for this grow; the last one goes once its icon has.
      final last = _heart;
      _heart = AnimationController(vsync: this);
      if (last != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => last.dispose());
      }
    });
    _listenForTapsOff(true);
    _listenForScroll(true);
    unawaited(_grow.forward());
  }

  /// Grows another of the author's posts from its photo on its pin: at once
  /// with the photo the pin has, the post itself (its full photo, its
  /// counts, its like and save) as it comes in.
  void _openOther(({TravelPin pin, String key}) spot) {
    final pin = spot.pin;
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
      key: spot.key,
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

  /// Back onto its pin with no animation (another post took this place).
  void _shrinkAtOnce() {
    _big = false;
    _listenForTapsOff(false);
    _listenForScroll(false);
    _shownId = null;
    _closeOther();
    _grow.value = 0;
  }

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
      _downOnCard = _isOnCard(event.position);
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
    // The card's own taps are its own (another one on its photo shrinks it).
    if (_downOnCard) return;
    _shrink();
  }

  /// The list went off screen, or came back: a grown card's video stops, or
  /// plays again.
  void _onScreenChanged() {
    if (mounted && _big) setState(() {});
  }

  /// The heart pops for a like on the grown card, not for taking one back.
  void _popHeart() {
    final heart = _heart;
    if (heart?.duration != null) unawaited(heart!.forward(from: 0));
  }

  void _onLikeTap() {
    if (_big && !widget.isLiked) _popHeart();
    widget.onLikeTap?.call();
  }

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mode = FeedGlobeMode.maybeOf(context);
    final photos = mode?.photosOnPins ?? false;
    final showPlace = mode?.showPlace ?? true;
    final viewport = FeedGlobeMode.viewportHeightOf(context);
    if (viewport != null) _measureAboveSoon();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final size = Size(width, _heightFor(width, viewport));
        return SizedBox.fromSize(
          size: size,
          child: !_loaded
              ? const ColoredBox(color: FeedPostGlobe._ground)
              : _globeIn(size, photos: photos, showPlace: showPlace),
        );
      },
    );
  }

  // --- its height -----------------------------------------------------------

  /// How far below its post's top a globe starts (the post's header), as
  /// last measured on any: a first guess for a globe not measured yet.
  static double _lastAbove = 60;

  /// How far below the list's top this globe starts with its post at the
  /// top: its own header — and, for the list's first post, what the list
  /// shows above it (the upload banner). Null until measured.
  double? _above;

  /// Fires when what is above the list's first post changes.
  Listenable? _aboveFirstPost;

  /// What this globe's height was last worked out with.
  double _aboveUsed = _lastAbove;
  double _naturalUsed = 0;
  double? _viewportUsed;
  bool _measuring = false;

  /// Under the globe, on screen: the gap over the line under the post (8),
  /// its top padding (4), the arrows, and a little room (8).
  static const double _below = 8 + 4 + FeedPostSteps.height + AppSpacing.sm;

  /// The least it is made, however short the screen.
  static const double _minHeight = 160;

  /// 4:5 ([AspectRatio]'s sum, to the bit) — or, where its post wouldn't fit
  /// the list's [viewport] with the arrows on screen, as much shorter as
  /// that takes.
  double _heightFor(double width, double? viewport) {
    final natural = width / (4 / 5);
    final above = _above ?? _lastAbove;
    _aboveUsed = above;
    _naturalUsed = natural;
    _viewportUsed = viewport;
    if (viewport == null) return natural;
    final room = viewport - above - _below;
    return room >= natural ? natural : math.max(room, _minHeight);
  }

  /// Measures, once laid out, how far down the list the globe starts with
  /// its post at the top: if that isn't what its height was worked out
  /// with, and it matters (the post doesn't fit with either), works it out
  /// again.
  void _measureAboveSoon() {
    if (_measuring) return;
    _measuring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measuring = false;
      final box = mounted ? context.findRenderObject() : null;
      if (box is! RenderBox || !box.attached) return;
      // The post: the list's own child holding the globe.
      RenderObject post = box;
      var list = post.parent;
      while (list != null && list is! RenderSliverMultiBoxAdaptor) {
        post = list;
        list = list.parent;
      }
      if (list is! RenderSliverMultiBoxAdaptor || post is! RenderBox) return;
      final header = box.localToGlobal(Offset.zero, ancestor: post).dy;
      _lastAbove = header;
      // The first post: below what the list shows over it.
      final data = post.parentData;
      final first = data is SliverMultiBoxAdaptorParentData && data.index == 0;
      final above =
          header + (first ? list.constraints.precedingScrollExtent : 0);
      final was = _aboveUsed;
      _above = above;
      final viewport = _viewportUsed;
      if (viewport == null || (above - was).abs() < 0.5) return;
      bool fits(double a) => viewport - a - _below >= _naturalUsed;
      if (fits(above) && fits(was)) return;
      setState(() {});
    });
  }

  Widget _globeIn(Size size, {required bool photos, required bool showPlace}) {
    final map = _map;
    final pin = _drawnPinNow();
    final place = photos
        ? PinCardPlace.photo(size: size, pin: pin, camera: _camera)
        : PinCardPlace.card(size: size, pin: pin, camera: _camera);
    if (pin != null) _camera ??= place.camera;
    // Grown: across the globe, in its middle (as high as fits).
    final width = math.max(
      place.card.width,
      math.min(
        size.width - 2 * _grownMargin,
        size.height - 2 * _grownMargin - PostPinCard.bigFooterHeight,
      ),
    );
    final grown = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: width,
      height: width + PostPinCard.bigFooterHeight,
    );
    return Stack(
      children: [
        Positioned.fill(
          // Counts the fingers on the globe (see [_fingersOnGlobe]); takes
          // nothing from it.
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _onGlobeDown,
            onPointerUp: _offGlobe,
            onPointerCancel: _offGlobe,
            child: GlobeView(
              // Built anew with each map, so it opens on the post.
              key: ValueKey('${widget.block.id}:$_shown'),
              controller: _globe,
              visitedCounts: map?.regions ?? const {},
              points: _points,
              viewerId: context.read<AppBloc>().state.user.id,
              initialCenter: _camera,
              // No pin for the post (none fetched): their travels, as on
              // their profile.
              faceTravels: pin == null,
              // A pin tapped opens the author's posts there, as on their
              // profile.
              onTargetTap: _openPlace,
              claimTap: _claimTap,
              // Its +, − and back-to-the-post buttons are drawn over the
              // posts on it (below), so a card turned into their corner
              // never covers them.
              showButtons: false,
              borderRadius: 0,
            ),
          ),
        ),
        // Its country and city, in the bottom left corner, level with the
        // globe's back-to-the-post button (the lowest of its three) and
        // clear of them. A label: touches go to the globe; the card can go
        // over it.
        if (showPlace)
          Positioned(
            left: FeedPostGlobe.buttonsInset,
            right: FeedPostGlobe.buttonsInset * 2 + GlobeButtons.size,
            bottom: FeedPostGlobe.buttonsInset,
            height: GlobeButtons.size,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FeedPostPlace(block: widget.block, map: map),
              ),
            ),
          ),
        // The posts on their pins, wherever the globe takes them.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: Listenable.merge([_growCurve, _globe.frames]),
            builder: (context, _) =>
                _onPins(box: size, place: place, grown: grown, photos: photos),
          ),
        ),
        // Taps on Trends' small photos (see [_photoHits]): heard, not taken,
        // so the globe still turns under a drag.
        if (photos)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onPhotosDown,
              onPointerMove: _onPhotosMove,
              onPointerUp: _onPhotosUp,
              onPointerCancel: _onPhotosCancel,
            ),
          ),
        // +, − and back to the post's place, as on the profile, in the bottom
        // right corner — over the posts on the globe (a card turned into the
        // corner never hides them); gone while a post is grown there.
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
        // How far they have travelled, as on their profile: over the card
        // when the globe takes it under (it takes no touches, so the card
        // under it still does).
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: TravelCountBadge(visited: map?.regions ?? const {}),
        ),
      ],
    );
  }

  /// The posts on their pins, in the [box] the globe fills: this post's on
  /// its pin (where it opens until the globe is laid out; growing to
  /// [grown]), and on Trends the author's other posts' around it — one per
  /// pin as drawn (a region's merge while zoomed out), the newest, none over
  /// another, none off the box or round the back.
  Widget _onPins({
    required Size box,
    required PinCardPlace place,
    required Rect grown,
    required bool photos,
  }) {
    final t = _growCurve.value;
    final size = place.card.size;
    final laidOut = _globe.isLaidOut;
    final drawn = laidOut ? _globe.pinsAt(_followed) : const <String, Offset>{};
    final spot = _spotKey;
    final at = spot == null ? null : drawn[spot];
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
      final onPin = PinCardPlace.over(at, size, withArrow: !photos);
      small = onPin.card;
      arrow = onPin.arrow;
    }

    // Another post grown, growing or shrinking: where it grows from.
    final shownOther = _other;
    final otherSmall = switch (shownOther == null
        ? null
        : drawn[shownOther.key]) {
      final where? => PinCardPlace.over(where, size).card,
      null => null,
    };

    // The others (Trends only), the newest first; one where another already
    // is goes, and one off the box (it would take an on-screen one's place
    // among the few shown).
    final taken = <Rect>[?small];
    final others = <(TravelPin, Rect)>[];
    final onBox = Offset.zero & box;
    for (final other in _others) {
      if (others.length >= _maxOthers) break;
      // Grown from its pin: drawn big below, not small here.
      if (other.pin.postId == _shownId) continue;
      final where = drawn[other.key];
      if (where == null) continue;
      final rect = PinCardPlace.over(where, size).card;
      if (!rect.overlaps(onBox)) continue;
      if (taken.any((placed) => _covers(placed, rect))) continue;
      taken.add(rect);
      others.add((other.pin, rect));
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
    // A video plays once grown, as on the long-press card; it waits while
    // the list is off screen.
    final playing = _big && _grow.isCompleted;
    final paused = !_isOnScreen;
    Widget thisCard({required double grown}) => PostPinCard(
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
      playVideo: thisShown && playing,
      videoPaused: paused,
      onPhotoTap: _onPhotoTap,
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
            child: OtherPinPhoto(url: pin.thumb!),
          ),
        // The new feed's card hangs from its arrow, gone as it grows.
        if (arrow != null && t < 1 && (thisShown || !_big))
          Positioned.fromRect(
            rect: arrow,
            child: Opacity(
              opacity: 1 - t.clamp(0.0, 1.0),
              child: const PinArrow(),
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
          _growing(
            from: small,
            to: grown,
            t: t,
            child: thisCard(grown: t),
          ),
        if (shownOther != null && (otherSmall != null || t > 0))
          _growing(
            from: otherSmall,
            to: grown,
            t: t,
            child: _OtherCard(
              key: _cardKey,
              other: shownOther,
              grown: t,
              big: _big,
              heart: _big ? _heart : null,
              playVideo: playing,
              videoPaused: paused,
              onPhotoTap: () => _big ? _shrink() : _expand(other: shownOther),
              onShareTap: widget.onShareTap,
              onCommentsTap: widget.onCommentsTap,
            ),
          ),
      ],
    );
  }

  /// A card [t] of the way from its pin ([from]) to [to]. Grown with its pin
  /// round the back (no [from]), it fades as it shrinks.
  static Widget _growing({
    required Rect? from,
    required Rect to,
    required double t,
    required Widget child,
  }) => Positioned.fromRect(
    rect: from == null ? to : Rect.lerp(from, to, t)!,
    child: Opacity(opacity: from == null ? t.clamp(0.0, 1.0) : 1, child: child),
  );

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

/// Another of the author's posts grown from its photo on its pin.
class _OtherPost {
  _OtherPost({
    required this.pin,
    required this.key,
    required this.bloc,
    required this.block,
  });

  final TravelPin pin;

  /// The key the globe knows its pin by.
  final String key;

  /// Its own likes, save and counts (the feed card's bloc is this post's).
  final PostBloc bloc;

  /// The post: a stand-in made from the pin (its photo) until it is in.
  PostBlock block;
  bool loaded = false;
}

/// [_OtherPost] grown: the same card as the post's own, with its own like,
/// save and counts; its buttons once the post is in (a like before its
/// counts are in would undo one already there).
class _OtherCard extends StatelessWidget {
  const _OtherCard({
    required this.other,
    required this.grown,
    required this.big,
    required this.playVideo,
    this.videoPaused = false,
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
  final bool videoPaused;
  final AnimationController? heart;
  final VoidCallback? onPhotoTap;
  final ValueSetter<PostBlock>? onShareTap;
  final ValueSetter<PostBlock>? onCommentsTap;

  @override
  Widget build(BuildContext context) {
    final loaded = other.loaded;
    return BlocBuilder<PostBloc, PostState>(
      bloc: other.bloc,
      builder: (context, state) => PostPinCard(
        block: other.block,
        photoOnly: true,
        isLiked: state.isLiked,
        isBookmarked: state.isBookmarked,
        likesCount: state.likes,
        commentsCount: state.commentsCount,
        grown: grown,
        big: big,
        heart: heart,
        playVideo: playVideo && loaded,
        videoPaused: videoPaused,
        onPhotoTap: onPhotoTap,
        onLikeTap: loaded
            ? () {
                // The heart pops for a like, not for taking one back.
                final heart = this.heart;
                if (!state.isLiked && heart?.duration != null) {
                  unawaited(heart!.forward(from: 0));
                }
                other.bloc.add(const PostLikeRequested());
              }
            : null,
        onSaveTap: loaded
            ? () => other.bloc.add(const PostBookmarkRequested())
            : null,
        onShareTap: loaded ? () => onShareTap?.call(other.block) : null,
        onCommentsTap: loaded ? () => onCommentsTap?.call(other.block) : null,
      ),
    );
  }
}

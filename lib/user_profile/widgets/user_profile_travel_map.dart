import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/map/map.dart';

/// Profile tab showing the user's "travel map": every ISO 3166-2 region they
/// have posted from is highlighted on an interactive globe. Nothing else.
///
/// The map fills the tab. It used to be pinned to a fixed height at the top,
/// which left dead space underneath once the profile header collapsed and the
/// tab grew.
class UserProfileTravelMap extends StatefulWidget {
  const UserProfileTravelMap({required this.userId, super.key});

  /// Breathing room so the map doesn't touch the panel edges.
  static const _inset = 5.0;

  final String userId;

  @override
  State<UserProfileTravelMap> createState() => _UserProfileTravelMapState();
}

class _UserProfileTravelMapState extends State<UserProfileTravelMap>
    with AutomaticKeepAliveClientMixin {
  /// Captured once; see [VisitedRegionsPage] — a per-build future resets the map.
  static final Future<void> _geoReady = GeoRegions.instance.load();

  // Keep the map alive across profile tab switches. Rebuilding it on every
  // return from the Posts tab re-subscribed its streams and re-fit the camera,
  // which is the stutter you see switching Posts → Map.
  @override
  bool get wantKeepAlive => true;

  /// The pinned app bar and tabs overlap the top of this tab (the header's
  /// overlap is absorbed, and a map tab has no sliver to inject it back), so
  /// the globe is kept in the part below them. The handle reports the overlap
  /// during the profile's own build and layout, when rebuilding is not
  /// allowed — so a change is picked up on the next frame.
  SliverOverlapAbsorberHandle? _overlapHandle;
  double _overlap = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handle = NestedScrollView.sliverOverlapAbsorberHandleFor(context);
    if (identical(handle, _overlapHandle)) return;
    _overlapHandle?.removeListener(_onOverlapChanged);
    _overlapHandle = handle..addListener(_onOverlapChanged);
    _overlap = handle.layoutExtent ?? 0;
    // On the first build the profile hasn't been laid out yet, so there is
    // no overlap to read until after this frame.
    _onOverlapChanged();
  }

  void _onOverlapChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlap = _overlapHandle?.layoutExtent ?? 0;
      if (mounted && overlap != _overlap) setState(() => _overlap = overlap);
    });
  }

  @override
  void dispose() {
    _overlapHandle?.removeListener(_onOverlapChanged);
    _unsubscribe();
    super.dispose();
  }

  // The travel data, kept here and subscribed to once. The streams used to be
  // created inside build, so every rebuild — any data change, the header
  // collapsing — closed the database queries and opened them again.
  final _subscriptions = <StreamSubscription<Object?>>[];
  Map<String, int> _visited = const {};
  List<({double lat, double lng, String? name})> _postPoints = const [];
  List<({double lat, double lng, String? name})> _storyPoints = const [];

  /// Posts' and stories' pins together. Rebuilt only when one of them
  /// changes, so the globe sees the same list until then and keeps what it
  /// worked out from it.
  List<({double lat, double lng, String? name})> _points = const [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant UserProfileTravelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId == widget.userId) return;
    _unsubscribe();
    _visited = const {};
    _postPoints = const [];
    _storyPoints = const [];
    _points = const [];
    _subscribe();
  }

  void _subscribe() {
    final posts = context.read<PostsRepository>();
    final userId = widget.userId;
    // Errors leave the last data in place, as the StreamBuilders did.
    void ignore(Object _) {}
    _subscriptions.addAll([
      // Story pins are counted in here too, by the region saved with each pin.
      posts
          .visitedRegionCountsOf(userId: userId)
          .listen(
            (visited) => setState(() => _visited = visited),
            onError: ignore,
          ),
      posts
          .visitedPointsOf(userId: userId)
          .listen(
            (points) => setState(() {
              _postPoints = points;
              _points = [..._postPoints, ..._storyPoints];
            }),
            onError: ignore,
          ),
      // Story locations also drop a pin — and they persist here even after
      // the 24h story has expired.
      posts
          .storyPointsOf(userId: userId)
          .listen(
            (points) => setState(() {
              _storyPoints = points;
              _points = [..._postPoints, ..._storyPoints];
            }),
            onError: ignore,
          ),
    ]);
  }

  void _unsubscribe() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // The globe draws the region polygons, so they must be in memory first.
    // `load()` caches, so this resolves instantly after the first call.
    return FutureBuilder<void>(
      future: _geoReady,
      builder: (context, _) => _buildMap(context),
    );
  }

  Widget _buildMap(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(UserProfileTravelMap._inset),
      // Fills whatever the tab gives it, header collapsed or not.
      child: GlobeView(
        visitedCounts: _visited,
        points: _points,
        autoRotate: true,
        padding: EdgeInsets.only(
          top: math.max(0, _overlap - UserProfileTravelMap._inset),
        ),
        onTargetTap: (target) => LocationPostsPage.push(
          context,
          userId: widget.userId,
          regionIso: target.region.iso,
          // Localized to the app language (matches the map labels).
          regionName: target.region.localizedDisplayName(
            Localizations.localeOf(context).languageCode,
          ),
          // The name the author gave this spot — the heading of the
          // page, since "Magic city bogi" is what they remember,
          // not the province it happens to fall in. User content —
          // never translated.
          placeName: target.point?.name,
          countryName: target.region.localizedCountryName(
            Localizations.localeOf(context).languageCode,
          ),
          scope: target.point == null
              ? LocationPostsScope.region
              : LocationPostsScope.point,
          lat: target.point?.lat,
          lng: target.point?.lng,
        ),
      ),
    );
  }
}

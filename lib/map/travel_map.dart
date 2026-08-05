import 'dart:async';
import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/map_base_layers.dart';

/// {@template travel_map}
/// An interactive world map (built on `flutter_map`, so pan / pinch-zoom /
/// fling behave like Google Maps) where each visited region in [visitedCounts]
/// is shaded by how many posts it holds (see [_colorForCount]). Country and
/// province names are rendered as map markers, so they stay glued to their
/// place and move with the map. More names appear the further you zoom in, each
/// sized to fit its region.
/// {@endtemplate}
/// What a tap on the map landed on.
///
/// [region] is always present — a pin only exists inside one. [point] is set
/// only when the tap actually hit a pin, which is what lets the caller show
/// "posts from this spot" rather than the whole region.
class TravelMapTarget {
  /// {@macro travel_map}
  const TravelMapTarget({required this.region, this.point});

  /// The region under the tap.
  final GeoRegion region;

  /// The pin that was hit, if any.
  final ({double lat, double lng, String? name})? point;
}

class TravelMap extends StatefulWidget {
  /// {@macro travel_map}
  const TravelMap({
    required this.visitedCounts,
    this.points = const [],
    this.height = 300,
    this.oceanColor,
    this.onTargetTap,
    this.tapAnyRegion = false,
    this.focusBounds,
    this.focusToken = 0,
    this.focusMaxZoom = 6,
    super.key,
  });

  /// ISO 3166-2 region code → number of posts placed in that region. The region
  /// is shaded by post density (0-20 light blue … 80+ red).
  final Map<String, int> visitedCounts;

  /// Exact `(lat, lng)` of each post — one pin per post (so two posts from the
  /// same city show two pins).
  final List<({double lat, double lng, String? name})> points;
  final double height;
  final Color? oceanColor;

  /// Called when a visited pin or region is tapped. Taps on the ocean, or on
  /// somewhere never posted from, are ignored — unless [tapAnyRegion].
  final ValueSetter<TravelMapTarget>? onTargetTap;

  /// Report taps on *any* region, visited or not. Onboarding uses this to let
  /// people mark places by tapping the map.
  final bool tapAnyRegion;

  /// Where the camera should sit. Applied on first load and whenever
  /// [focusToken] changes.
  final LatLngBounds? focusBounds;

  /// Bump this to request a fly-to. Comparing bounds objects instead was
  /// unreliable — an incidental rebuild could re-fit the camera and yank the
  /// map back while you were looking at it.
  final int focusToken;

  /// Ceiling for a fly-to. Without it a tiny region (a city province) fits at
  /// an extreme zoom, which then visibly snaps back once the camera
  /// constraint applies.
  final double focusMaxZoom;

  @override
  State<TravelMap> createState() => _TravelMapState();
}

class _TravelMapState extends State<TravelMap> {
  final _controller = MapController();

  /// You can't zoom out past the home view — further out just adds empty grey
  /// margins above and below the world, which looks broken.
  static const _minZoom = _homeZoom;
  static const _maxZoom = 11.0;

  /// The extent of the drawn map (Antarctica is not drawn — see
  /// [MapBaseLayers]). The camera is *contained* by this, so you can never pan
  /// off into blank ocean: the land always reaches the panel edges.
  static final _contentBounds = LatLngBounds(
    const LatLng(-58, -180),
    const LatLng(84, 180),
  );

  /// The view the map opens (and resets) to — and, since [_minZoom] equals it,
  /// the furthest you can zoom out. The design asks for provinces to stay
  /// readable, so the world view is deliberately not reachable: the widest
  /// shot is a continent with its regions visible.
  // Central Europe (≈ Germany): Spain, Germany, Poland and neighbours in view.
  static const _homeCenter = LatLng(50, 10);
  static const _homeZoom = 3.0;

  // Base geometry is built once per session and shared (see MapBaseLayers).
  List<Polygon> get _countryOutlines => MapBaseLayers.instance.countryOutlines;
  List<Polygon> get _provinceBorders => MapBaseLayers.instance.provinceBorders;
  late final Future<void> _future = _init();

  Future<void> _init() async {
    await MapBaseLayers.instance.build();
    await _loadSeenPoints();
  }

  /// Province borders only kick in from this zoom (world view = countries only).
  static const _provinceZoom = 3.0;

  /// Pin labels would overlap into mush at continent scale, so the place name
  /// only appears once you are zoomed past this.
  static const _placeNameZoom = 5.0;

  double _zoom = _homeZoom;
  LatLngBounds? _bounds;

  /// Points whose posts have been opened. A seen pin dims to [_seenPinColor];
  /// unopened pins stay white. Persisted, so it survives a relaunch.
  final _seenPoints = <String>{};

  static const _seenStoreKey = 'treepnet_seen_map_pins';

  static String _pointKey(double lat, double lng) => '$lat,$lng';

  Future<void> _loadSeenPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_seenStoreKey);
    if (stored == null || stored.isEmpty || !mounted) return;
    _safeSetState(() => _seenPoints.addAll(stored));
  }

  Future<void> _rememberSeenPoint(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenStoreKey, _seenPoints.toList());
  }

  /// A pin dims to this once you have opened the posts behind it.
  static const _seenPinColor = Color(0xFF414141);

  /// Shaded-region polygons, built once per change of [TravelMap.visitedCounts]
  /// rather than on every build. `onPositionChanged` calls `setState` on every
  /// frame of a pan or zoom, and rebuilding thousands of ring points each time
  /// froze the map and made it stutter.
  List<Polygon> _visited = const [];
  bool _visitedDirty = true;

  /// Ring→polygon conversion is the expensive part, and it only depends on the
  /// region and its colour — so keep it across rebuilds.
  final _polygonCache = <String, List<Polygon>>{};

  Color get _oceanColor => widget.oceanColor ?? MapBaseLayers.oceanColor;

  void _zoomBy(double delta) {
    final c = _controller.camera;
    _controller.move(c.center, (c.zoom + delta).clamp(_minZoom, _maxZoom));
  }

  /// `flutter_map` fires `onMapReady` / `onPositionChanged` while it is laying
  /// out (e.g. right after `fitCamera`). Calling `setState` then throws
  /// "setState() called during build" and Flutter swaps the map for a red error
  /// box — which is exactly what happened when a post was deleted and the map
  /// rebuilt. Defer to the next frame in that case.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    final building =
        phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks;
    if (building) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    } else {
      setState(fn);
    }
  }

  @override
  void didUpdateWidget(covariant TravelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameCounts(widget.visitedCounts, oldWidget.visitedCounts)) {
      _visitedDirty = true;
    }
    final bounds = widget.focusBounds;
    if (bounds != null && widget.focusToken != oldWidget.focusToken) {
      _fitBounds(bounds);
    }
  }

  /// Snaps to the home view. A plain `fitCamera` was unreliable here: it runs
  /// from `onMapReady`, before the map has been laid out, so it computed a
  /// bogus (non-finite) zoom and was skipped — leaving the map on its initial
  /// camera. Moving to a fixed centre/zoom is deterministic.
  void _fitHome() => _controller.move(_homeCenter, _homeZoom);

  /// Built once. `MapOptions` created inline compares unequal on every rebuild
  /// (the callbacks are fresh closures each time), and flutter_map responds by
  /// resetting the camera to `initialCenter`/`initialZoom` — which yanked the
  /// map back to the whole-world view every time anything changed.
  late final MapOptions _mapOptions = MapOptions(
    initialCenter: _homeCenter,
    initialZoom: _homeZoom,
    minZoom: _minZoom,
    maxZoom: _maxZoom,
    backgroundColor: _oceanColor,
    // Keep the camera CENTRE within the drawn map so panning
    // stays near land. We deliberately use `containCenter`
    // rather than `contain`: `contain` re-fits the camera on
    // every viewport change and, while a profile tab is
    // animating in (its size interpolating frame by frame),
    // flutter_map asserts the live camera no longer satisfies
    // the constraint and swaps the map for a red error box.
    // `containCenter` only clamps the centre, so transient
    // viewport sizes never invalidate the camera.
    cameraConstraint: CameraConstraint.containCenter(bounds: _contentBounds),
    interactionOptions: const InteractionOptions(
      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    ),
    onTap: _onMapTap,
    onMapReady: _onMapReady,
    onPositionChanged: _onPositionChanged,
  );

  void _onMapReady() {
    final focus = widget.focusBounds;
    if (focus != null) {
      _fitBounds(focus);
    } else {
      _fitHome();
    }
    final camera = _controller.camera;
    if (!camera.zoom.isFinite) return;
    _safeSetState(() {
      _zoom = camera.zoom;
      _bounds = camera.visibleBounds;
    });
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final zoom = camera.zoom;
    // Mid-resize (profile header collapsing) flutter_map can report a
    // non-finite zoom; ignore those frames.
    if (!zoom.isFinite) return;
    final bounds = camera.visibleBounds;
    _safeSetState(() {
      _zoom = zoom;
      _bounds = bounds;
    });
  }

  void _reset() => _fitHome();

  /// Frames [bounds]. Deferred a frame: the controller rejects a move while
  /// the map is still laying out.
  void _fitBounds(LatLngBounds bounds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(16),
          maxZoom: widget.focusMaxZoom,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ColoredBox(
                color: _oceanColor,
                child: const Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (_visitedDirty) {
              _visited = _visitedPolygons();
              _visitedDirty = false;
            }
            final visited = _visited;
            return Stack(
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: _mapOptions,
                  children: [
                    PolygonLayer(
                      polygons: _countryOutlines,
                      simplificationTolerance: 0.6,
                    ),
                    if (_zoom >= _provinceZoom)
                      PolygonLayer(
                        polygons: _provinceBorders,
                        simplificationTolerance: 0.4,
                      ),
                    if (visited.isNotEmpty)
                      PolygonLayer(
                        polygons: visited,
                        simplificationTolerance: 0,
                      ),
                    MarkerLayer(markers: _pinMarkers()),
                    MarkerLayer(markers: _labelMarkers()),
                  ],
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                      const SizedBox(height: 8),
                      _MapButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                      const SizedBox(height: 8),
                      _MapButton(icon: Icons.my_location, onTap: _reset),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _sameCounts(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  List<Polygon> _visitedPolygons() {
    final geo = GeoRegions.instance;
    final polygons = <Polygon>[];
    for (final entry in widget.visitedCounts.entries) {
      final region = geo.regionByIso(entry.key);
      if (region == null) continue;
      final color = _colorForCount(entry.value);
      final cacheKey = '${entry.key}:${color.toARGB32()}';
      polygons.addAll(
        _polygonCache.putIfAbsent(cacheKey, () {
          final built = <Polygon>[];
          for (final ring in region.rings) {
            if (ring.length < 3) continue;
            built.add(
              Polygon(
                points: [for (final p in ring) LatLng(p.dy, p.dx)],
                color: color.withValues(alpha: 0.85),
                borderColor: AppColors.white,
                borderStrokeWidth: 1,
              ),
            );
          }
          return built;
        }),
      );
    }
    return polygons;
  }

  /// How near a tap must land (in logical pixels) to count as hitting a pin.
  /// Roughly a fingertip: the pin icon itself is only 26px wide.
  static const _pinHitRadius = 24.0;

  /// Resolves a tap to a pin, else to the region under it.
  ///
  /// Pins win over regions when both are hit, since a pin is the more specific
  /// answer to "what did I tap".
  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    final onTargetTap = widget.onTargetTap;
    if (onTargetTap == null) return;

    final hit = _pinAt(tapPosition.relative);
    final probe =
        hit ?? (lat: latLng.latitude, lng: latLng.longitude, name: null);
    final region = GeoRegions.instance.regionAt(probe.lng, probe.lat);

    // Ocean: nothing under the tap.
    if (region == null) return;
    // On the travel map, only a pin opens a place. A bare tap on a province —
    // even a visited one — does nothing; its whole-region feed is reached from
    // the "See the whole region" button inside a pin's page. Onboarding sets
    // [tapAnyRegion] to keep letting people mark provinces by tapping.
    if (!widget.tapAnyRegion && hit == null) return;

    onTargetTap(TravelMapTarget(region: region, point: hit));

    // Opening a pin's posts marks it seen — it dims, and stays dimmed.
    if (hit != null) {
      final key = _pointKey(hit.lat, hit.lng);
      if (_seenPoints.add(key)) {
        _safeSetState(() {});
        unawaited(_rememberSeenPoint(key));
      }
    }
  }

  /// The pin nearest [tap] within [_pinHitRadius], or null.
  ({double lat, double lng, String? name})? _pinAt(Offset? tap) {
    if (tap == null || widget.points.isEmpty) return null;
    final camera = _controller.camera;
    ({double lat, double lng, String? name})? best;
    var bestDistance = double.infinity;
    for (final p in widget.points) {
      final screen = camera.latLngToScreenPoint(LatLng(p.lat, p.lng));
      final distance = math.sqrt(
        math.pow(screen.x - tap.dx, 2) + math.pow(screen.y - tap.dy, 2),
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        best = p;
      }
    }
    return bestDistance <= _pinHitRadius ? best : null;
  }

  List<Marker> _pinMarkers() {
    return [
      for (final p in widget.points)
        Marker(
          point: LatLng(p.lat, p.lng),
          width: 96,
          height: 62,
          // The pin's tip (bottom of the icon) sits on the exact point.
          // Grey until its posts are opened, then white. The name the author
          // gave the spot rides just under it, so everyone can read it.
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  // White until you open its posts, then it dims to #414141.
                  color: _seenPoints.contains(_pointKey(p.lat, p.lng))
                      ? _seenPinColor
                      : AppColors.white,
                  size: 26,
                  shadows: const [
                    Shadow(color: AppColors.black, blurRadius: 3),
                  ],
                ),
                if (_zoom >= _placeNameZoom &&
                    p.name != null &&
                    p.name!.trim().isNotEmpty)
                  Text(
                    p.name!,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      height: 1,
                      // Heaviest label on the map: a place the user named
                      // outranks the country/province names underneath it.
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: AppColors.black, blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  /// Approximate pixels-per-degree of longitude at the current zoom (Web
  /// Mercator: 256px tiles doubling each zoom level).
  double get _pxPerDeg => 256 * math.pow(2, _zoom) / 360;

  List<Marker> _labelMarkers() {
    final bounds = _bounds;
    if (bounds == null) return const [];
    // While the profile header collapses, the map is briefly laid out with a
    // zero height and flutter_map reports a non-finite zoom. A NaN would flow
    // into the marker sizes below and blow up the render tree (red error box),
    // so bail out until the camera is sane again.
    if (!_zoom.isFinite) return const [];
    final geo = GeoRegions.instance;
    final ppd = _pxPerDeg;
    if (!ppd.isFinite || ppd <= 0) return const [];
    final markers = <Marker>[];

    // Country names: appear once the country is wide enough on screen.
    for (final c in geo.countryLabels) {
      final span = c.spanDeg * ppd;
      if (span < 55 || span > 900) continue;
      final ll = LatLng(c.center.dy, c.center.dx);
      if (!bounds.contains(ll)) continue;
      markers.add(
        _fittedLabel(
          ll,
          c.name.toUpperCase(),
          width: span.clamp(40, 150),
          height: (span * 0.5).clamp(16, 44),
          color: AppColors.white,
          weight: FontWeight.w600,
        ),
      );
    }

    // Province names: only when zoomed in, sized to each province.
    if (_zoom >= 4.5) {
      // A pin the user named after the province it sits in would print the
      // same word twice, so that province gets the suffix too. (Provinces that
      // share a name with their capital are already flagged at load time.)
      final pinNames = <String>{
        for (final p in widget.points)
          if (p.name != null && p.name!.trim().isNotEmpty)
            p.name!.trim().toLowerCase(),
      };
      for (final region in geo.allRegions) {
        final b = region.lngLatBounds;
        if (b == Rect.zero) continue;
        final w = b.width * ppd;
        if (w < 42) continue;
        final ll = LatLng(region.centroidLngLat.dy, region.centroidLngLat.dx);
        if (!bounds.contains(ll)) continue;
        final clashesWithPin =
            !region.sharesNameWithCity &&
            (pinNames.contains(region.name.trim().toLowerCase()) ||
                region.name.trim().toLowerCase() ==
                    region.countryName.trim().toLowerCase());
        markers.add(
          _fittedLabel(
            ll,
            clashesWithPin ? '${region.name} Region' : region.displayName,
            width: w.clamp(36, 140),
            height: (b.height * ppd * 0.7).clamp(14, 34),
            color: const Color(0xFFDCE6FF),
            weight: FontWeight.w600,
          ),
        );
      }
    }
    return markers;
  }

  /// A label marker whose text is scaled (via [FittedBox]) to fit the region's
  /// on-screen box, so it never spills past the region and grows/shrinks with
  /// it.
  Marker _fittedLabel(
    LatLng point,
    String text, {
    required double width,
    required double height,
    required Color color,
    required FontWeight weight,
  }) {
    // A NaN/Infinity slipping into a marker's size crashes the render tree, so
    // never hand one out — clamp to a sane box no matter what came in.
    final w = width.isFinite ? width.clamp(8.0, 300.0) : 40.0;
    final h = height.isFinite ? height.clamp(8.0, 80.0) : 16.0;
    return Marker(
      point: point,
      width: w,
      height: h,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: weight,
            fontSize: 13,
            height: 1,
            shadows: const [Shadow(color: AppColors.black, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  /// Shades a region by how many posts it holds, matching the referral badge
  /// tier colours: 0-20 light blue, 21-40 dark blue, 41-60 purple, 61-80 pink,
  /// 80+ red.
  static Color _colorForCount(int count) {
    if (count <= 20) return const Color(0xFF5BB8E8); // light blue
    if (count <= 40) return const Color(0xFF1E7FE0); // dark blue
    if (count <= 60) return const Color(0xFFA020C7); // purple
    if (count <= 80) return const Color(0xFFED2A93); // pink
    return const Color(0xFFE01B24); // red (80+)
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}

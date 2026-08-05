import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/map_base_layers.dart';

/// The outcome of the map location picker: the resolved [region] plus the exact
/// [lat]/[lng] the pin was dropped on (so each post keeps its precise spot).
class PickedLocation {
  const PickedLocation({
    required this.region,
    required this.lat,
    required this.lng,
    this.placeName,
  });

  final GeoRegion region;
  final double lat;
  final double lng;

  /// The custom name the user typed for this spot (e.g. "Kiz Kulesi"). Falls
  /// back to the region name when empty.
  final String? placeName;
}

/// Opens the full-screen map picker and returns the chosen [PickedLocation],
/// or null if cancelled.
Future<PickedLocation?> showLocationPicker(BuildContext context) {
  // Must go on the root navigator: the story editor is pushed there, so a
  // picker opened on the shell navigator would slide in *underneath* it and
  // look like nothing happened.
  return Navigator.of(context, rootNavigator: true).push<PickedLocation>(
    MaterialPageRoute(builder: (_) => const LocationPickerPage()),
  );
}

/// {@template location_picker_page}
/// A Google-Maps-style location picker: a pin stays fixed in the centre while
/// the map moves behind it, and wherever the pin lands is reverse-geocoded to a
/// region. Confirming returns that region + the exact coordinates.
/// {@endtemplate}
class LocationPickerPage extends StatefulWidget {
  /// {@macro location_picker_page}
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _controller = MapController();
  final _random = math.Random();
  final _placeController = TextEditingController();
  final _searchController = TextEditingController();

  static const _ocean = MapBaseLayers.oceanColor;
  static const _provinceZoom = 3.0;

  /// The existing pin whose name was copied into the field, if any.
  ({double lat, double lng})? _autoFilledAt;

  /// Set when confirming with an empty name, to show the warning.
  bool _nameMissing = false;

  /// Places matching what's typed in the search box (max [_maxSuggestions]).
  List<GeoRegion> _suggestions = const [];
  static const _maxSuggestions = 6;

  /// The signed-in user's own travel map, drawn underneath the picker so you
  /// can see (and re-pick) somewhere you have already been.
  List<({double lat, double lng, String? name})> _myPoints = const [];
  List<Polygon> _myPolygons = const [];

  Future<void> _loadMyMap() async {
    final userId = context.read<AppBloc>().state.user.id;
    if (userId.isEmpty) return;
    final posts = context.read<PostsRepository>();
    final regions = await posts.visitedRegionCountsOf(userId: userId).first;
    final points = await posts.visitedPointsOf(userId: userId).first;
    if (!mounted) return;
    _safeSetState(() {
      _myPoints = points;
      _myPolygons = _buildMyPolygons(regions);
    });
  }

  /// Same shading the profile map uses: post density per region.
  static List<Polygon> _buildMyPolygons(Map<String, int> counts) {
    final geo = GeoRegions.instance;
    final polygons = <Polygon>[];
    for (final entry in counts.entries) {
      final region = geo.regionByIso(entry.key);
      if (region == null) continue;
      final colour = _colorForCount(entry.value);
      for (final ring in region.rings) {
        if (ring.length < 3) continue;
        polygons.add(
          Polygon(
            points: [for (final p in ring) LatLng(p.dy, p.dx)],
            color: colour.withValues(alpha: 0.85),
            borderColor: AppColors.white,
            borderStrokeWidth: 1,
          ),
        );
      }
    }
    return polygons;
  }

  static Color _colorForCount(int count) {
    if (count <= 20) return const Color(0xFF5BB8E8);
    if (count <= 40) return const Color(0xFF1E7FE0);
    if (count <= 60) return const Color(0xFFA020C7);
    if (count <= 80) return const Color(0xFFED2A93);
    return const Color(0xFFE01B24);
  }

  /// Country and province names, sized to the region they sit on — the same
  /// treatment the profile map uses so the two read alike.
  List<Marker> _regionLabels() {
    if (!_zoom.isFinite) return const [];
    final geo = GeoRegions.instance;
    final ppd = 256 * math.pow(2, _zoom) / 360;
    if (!ppd.isFinite || ppd <= 0) return const [];
    final markers = <Marker>[];

    for (final c in geo.countryLabels) {
      final span = c.spanDeg * ppd;
      if (span < 55 || span > 900) continue;
      markers.add(
        _label(
          LatLng(c.center.dy, c.center.dx),
          c.name.toUpperCase(),
          width: span.clamp(40, 150).toDouble(),
          height: (span * 0.5).clamp(16, 44).toDouble(),
          color: AppColors.white,
          weight: FontWeight.w600,
        ),
      );
    }

    if (_zoom >= 4.5) {
      for (final region in geo.allRegions) {
        final b = region.lngLatBounds;
        if (b == Rect.zero) continue;
        final w = b.width * ppd;
        if (w < 42) continue;
        markers.add(
          _label(
            LatLng(region.centroidLngLat.dy, region.centroidLngLat.dx),
            region.name,
            width: w.clamp(36, 140).toDouble(),
            height: (b.height * ppd * 0.7).clamp(14, 34).toDouble(),
            color: const Color(0xFFDCE6FF),
            weight: FontWeight.w600,
          ),
        );
      }
    }
    return markers;
  }

  Marker _label(
    LatLng point,
    String text, {
    required double width,
    required double height,
    required Color color,
    required FontWeight weight,
  }) {
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

  /// Tapping one of your existing places re-picks it.
  void _onMapTap(TapPosition tap, LatLng latLng) {
    if (_myPoints.isEmpty) return;
    final camera = _controller.camera;
    final at = tap.relative;
    if (at == null) return;
    ({double lat, double lng, String? name})? best;
    var bestDistance = double.infinity;
    for (final p in _myPoints) {
      final screen = camera.latLngToScreenPoint(LatLng(p.lat, p.lng));
      final d = math.sqrt(
        math.pow(screen.x - at.dx, 2) + math.pow(screen.y - at.dy, 2),
      );
      if (d < bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
    if (best == null || bestDistance > 28) return;
    _controller.move(LatLng(best.lat, best.lng), math.max(_zoom, 6));
    final name = best.name;
    if (name != null && name.trim().isNotEmpty) {
      _placeController.text = name;
      // Remember where it came from: drag the pin off this spot and the
      // borrowed name no longer describes it, so it gets cleared.
      _autoFilledAt = (lat: best.lat, lng: best.lng);
    }
  }

  @override
  void initState() {
    super.initState();
    _placeController.addListener(_onPlaceNameChanged);
  }

  @override
  void dispose() {
    _placeController
      ..removeListener(_onPlaceNameChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPlaceNameChanged() => _safeSetState(() {
    if (_placeController.text.trim().isNotEmpty) _nameMissing = false;
  });

  void _onSearchChanged(String raw) {
    final query = raw.trim().toLowerCase();
    if (query.isEmpty) {
      _safeSetState(() => _suggestions = const []);
      return;
    }
    final matches = <GeoRegion>[];
    for (final region in GeoRegions.instance.allRegions) {
      if (region.name.toLowerCase().startsWith(query) ||
          region.countryName.toLowerCase().startsWith(query)) {
        matches.add(region);
        if (matches.length >= _maxSuggestions) break;
      }
    }
    _safeSetState(() => _suggestions = matches);
  }

  /// Flies to a searched place. The camera lands *inside* the region but off
  /// its centre — the centre is where the map prints the place's own name, so
  /// a pin dropped there buries the user's label under the city label.
  ///
  /// Panning by hand afterwards still wins: this only runs when a search
  /// result is tapped, and the pin is wherever the camera ends up.
  void _goTo(GeoRegion region) {
    FocusScope.of(context).unfocus();
    // Keep what was picked visible in the box — clearing it made the screen
    // look like the search had been thrown away. displayName so a province
    // shows as "Tashkent Region", matching the dropdown and the map.
    _searchController.text = region.displayName;
    _safeSetState(() => _suggestions = const []);
    _controller.move(_spotInside(region), 6);
  }

  /// A random point that is inside [region] yet clear of its centre, so naming
  /// the same city twice drops two distinct pins instead of stacking them.
  LatLng _spotInside(GeoRegion region) {
    final centre = region.centroidLngLat;
    final fallback = LatLng(centre.dy, centre.dx);
    final bounds = region.lngLatBounds;
    if (bounds == Rect.zero) return fallback;

    final geo = GeoRegions.instance;
    for (var attempt = 0; attempt < 30; attempt++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      // 30-65% of the way to the edge: past the centre label, still well
      // short of the border.
      final reach = 0.3 + _random.nextDouble() * 0.35;
      final lng = centre.dx + math.cos(angle) * (bounds.width / 2) * reach;
      final lat = centre.dy + math.sin(angle) * (bounds.height / 2) * reach;
      // Only accept it if it really is this region — bounding boxes overrun
      // coastlines and odd shapes badly.
      if (geo.regionAt(lng, lat)?.iso == region.iso) {
        return LatLng(lat, lng);
      }
    }
    return fallback;
  }

  // Shared, built once per session (see MapBaseLayers) — no long spinner.
  List<Polygon> get _countryOutlines => MapBaseLayers.instance.countryOutlines;
  List<Polygon> get _provinceBorders => MapBaseLayers.instance.provinceBorders;
  late final Future<void> _future = _init();

  double _zoom = 3;
  // Central Europe (≈ Germany) as the opening view — Spain/Germany/Poland.
  LatLng _center = const LatLng(50, 10);
  GeoRegion? _detected;

  Future<void> _init() async {
    await MapBaseLayers.instance.build();
    _detect();
    await _loadMyMap();
  }

  /// `flutter_map` can fire `onPositionChanged` while laying out, and calling
  /// `setState` then throws "setState() called during build". Defer if so.
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

  void _detect() {
    _safeSetState(() {
      _detected = GeoRegions.instance.regionAt(
        _center.longitude,
        _center.latitude,
      );
    });
  }

  void _zoomBy(double d) {
    final c = _controller.camera;
    _controller.move(c.center, (c.zoom + d).clamp(0.7, 12));
  }

  /// Whether the tick does anything. Deliberately NOT gated on the name: a
  /// disabled tick can't explain itself, so it stays tappable and [_confirm]
  /// turns the name field red instead.
  bool get _canConfirm => _detected != null;

  /// Whether the tick looks ready — everything needed has been filled in.
  bool get _isComplete =>
      _detected != null && _placeController.text.trim().isNotEmpty;

  /// Drops the name copied from an existing pin once the map has been dragged
  /// off that pin — the name belonged to that spot, not to this new one.
  void _clearBorrowedName() {
    final from = _autoFilledAt;
    if (from == null) return;
    const tolerance = 0.02; // degrees — a nudge, not a real move
    final moved =
        (from.lat - _center.latitude).abs() > tolerance ||
        (from.lng - _center.longitude).abs() > tolerance;
    if (!moved) return;
    _autoFilledAt = null;
    _safeSetState(() => _placeController.clear());
  }

  void _confirm() {
    final region = _detected;
    if (region == null) return;
    final name = _placeController.text.trim();
    // A place without a name is not a place anyone can read on the map.
    if (name.isEmpty) {
      _safeSetState(() => _nameMissing = true);
      return;
    }
    Navigator.of(context).pop(
      PickedLocation(
        region: region,
        lat: _center.latitude,
        lng: _center.longitude,
        placeName: name.isEmpty ? null : name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ocean,
      // Design: back arrow, a search box, and a tick that confirms — the
      // title row doubles as the place search.
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.inputSpace,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: AppColors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: context.l10n.searchText,
                    hintStyle: const TextStyle(color: AppColors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.check,
              color: _isComplete ? AppColors.white : AppColors.grey,
            ),
            onPressed: _canConfirm ? _confirm : null,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  // Don't let the world shrink smaller than the screen.
                  minZoom: 0.7,
                  maxZoom: 12,
                  backgroundColor: _ocean,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: _onMapTap,
                  onPositionChanged: (camera, _) {
                    _center = camera.center;
                    _zoom = camera.zoom;
                    _clearBorrowedName();
                    _detect();
                  },
                ),
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
                  // Your own travel map underneath: shaded regions and a pin
                  // for every place you have posted from.
                  if (_myPolygons.isNotEmpty)
                    PolygonLayer(
                      polygons: _myPolygons,
                      simplificationTolerance: 0,
                    ),
                  // Country / province names, same as the profile map.
                  MarkerLayer(markers: _regionLabels()),
                  MarkerLayer(
                    markers: [
                      for (final p in _myPoints)
                        Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 96,
                          height: 58,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.white,
                                  size: 22,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.black,
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                if (p.name != null && p.name!.trim().isNotEmpty)
                                  Text(
                                    p.name!,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontSize: 11,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: AppColors.black,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // Fixed centre pin — its tip marks the picked point. White fill
              // with a dark outline so it stands out over any map colour.
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 44),
                    child: Icon(
                      Icons.location_on,
                      color: AppColors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 130,
                child: Column(
                  children: [
                    _MapButton(icon: Icons.add, onTap: () => _zoomBy(1)),
                    const SizedBox(height: 10),
                    _MapButton(icon: Icons.remove, onTap: () => _zoomBy(-1)),
                  ],
                ),
              ),
              // Bottom: name this exact spot (design puts only this here —
              // confirming is the tick in the app bar).
              Positioned(
                left: 16,
                right: 16,
                bottom: 45,
                child: _PlaceNameField(
                  region: _detected,
                  controller: _placeController,
                  showError: _nameMissing,
                ),
              ),
              // Search results drop under the search box.
              if (_suggestions.isNotEmpty)
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: _SearchResults(
                    regions: _suggestions,
                    onSelected: _goTo,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The bottom field from the design: name this exact spot. The detected
/// region is shown above it so you know what you are naming.
class _PlaceNameField extends StatelessWidget {
  const _PlaceNameField({
    required this.region,
    required this.controller,
    this.showError = false,
  });

  /// Highlights the field when confirm was pressed with nothing typed.
  final bool showError;

  final GeoRegion? region;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final has = region != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: has,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            hintText: context.l10n.nameOfLocationText,
            hintStyle: const TextStyle(color: AppColors.grey),
            filled: true,
            fillColor: AppColors.inputSpace,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            errorText: showError ? context.l10n.nameLocationErrorText : null,
            errorStyle: const TextStyle(color: AppColors.red),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: showError
                  ? const BorderSide(color: AppColors.red)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.white),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Autocomplete panel under the search box: matching places, each tagged with
/// what it is.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.regions, required this.onSelected});

  final List<GeoRegion> regions;
  final ValueSetter<GeoRegion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.inputSpace,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final region in regions)
            InkWell(
              onTap: () => onSelected(region),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        // displayName, not name: a province that shares a city's
                        // name reads "Tashkent Region" so the two entries are
                        // told apart, exactly as the map labels them.
                        region.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      region.countryName,
                      style: const TextStyle(
                        color: AppColors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

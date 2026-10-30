import 'dart:math' as math;

import 'package:app_ui/app_ui.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';
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
/// A Google-Maps-style location picker on the globe: a pin stays fixed in the
/// centre while the globe turns behind it, and wherever the pin lands is
/// reverse-geocoded to a region. Confirming returns that region + the exact
/// coordinates.
/// {@endtemplate}
class LocationPickerPage extends StatefulWidget {
  /// {@macro location_picker_page}
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  /// The globe's centre is the picked spot (see [_onGlobeMoved]).
  final _globeController = GlobeController();
  final _random = math.Random();
  final _placeController = TextEditingController();
  final _searchController = TextEditingController();

  static const _ocean = MapBaseLayers.oceanColor;

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

  /// Posts (and stories) per region, shaded like the profile map.
  Map<String, int> _myCounts = const {};

  Future<void> _loadMyMap() async {
    final userId = context.read<AppBloc>().state.user.id;
    if (userId.isEmpty) return;
    final posts = context.read<PostsRepository>();
    final regions = await posts.visitedRegionCountsOf(userId: userId).first;
    final postPoints = await posts.visitedPointsOf(userId: userId).first;
    final storyPoints = await posts.storyPointsOf(userId: userId).first;
    // Needed to reverse-geocode story points into their regions below.
    await GeoRegions.instance.load();
    if (!mounted) return;
    // Show BOTH post locations and story-only locations (a place pinned with
    // just a story, no post yet), deduped by coordinate — so every place on the
    // profile map can be re-picked here and have a post added to it. Posts win
    // ties so a spot with both keeps its post name.
    final seen = <String>{};
    final merged = <({double lat, double lng, String? name})>[];
    for (final p in [...postPoints, ...storyPoints]) {
      if (seen.add('${p.lat},${p.lng}')) merged.add(p);
    }
    // Region shading counts posts plus the regions story points fall in
    // (reverse-geocoded), matching the profile map so a story-only region is
    // shaded too.
    final counts = Map<String, int>.of(regions);
    final geo = GeoRegions.instance;
    for (final p in storyPoints) {
      final region = geo.regionAt(p.lng, p.lat);
      if (region != null) {
        counts.update(region.iso, (c) => c + 1, ifAbsent: () => 1);
      }
    }
    _safeSetState(() {
      _myPoints = merged;
      _myCounts = counts;
    });
  }

  /// Tapping one of your existing places re-picks it: centre on it and borrow
  /// its name. The globe reports taps on its pins here.
  void _repick(({double lat, double lng, String? name}) place) {
    _globeController.moveTo(place.lat, place.lng, zoom: math.max(_zoom, 6));
    final name = place.name;
    if (name != null && name.trim().isNotEmpty) {
      _placeController.text = name;
      // Remember where it came from: drag the pin off this spot and the
      // borrowed name no longer describes it, so it gets cleared.
      _autoFilledAt = (lat: place.lat, lng: place.lng);
    }
  }

  @override
  void initState() {
    super.initState();
    _placeController.addListener(_onPlaceNameChanged);
    _globeController.addListener(_onGlobeMoved);
  }

  @override
  void dispose() {
    _placeController
      ..removeListener(_onPlaceNameChanged)
      ..dispose();
    _searchController.dispose();
    _globeController
      ..removeListener(_onGlobeMoved)
      ..dispose();
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
      // Match source + English + Russian names (region and country) so search
      // works in either script regardless of the app language.
      if (region.name.toLowerCase().startsWith(query) ||
          region.nameEn.toLowerCase().startsWith(query) ||
          region.nameRu.toLowerCase().startsWith(query) ||
          region.countryName.toLowerCase().startsWith(query) ||
          region.countryNameRu.toLowerCase().startsWith(query)) {
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
    _searchController.text = region.localizedDisplayName(
      Localizations.localeOf(context).languageCode,
    );
    _safeSetState(() => _suggestions = const []);
    final spot = _spotInside(region);
    _globeController.moveTo(
      spot.latitude,
      spot.longitude,
      zoom: 6,
      animate: true,
    );
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

  late final Future<void> _future = _init();

  /// The picked spot and the scale (as a flat-map zoom level), kept current
  /// on every globe frame — they're read on confirm. The globe opens whole,
  /// over your own travels like the profile globe, and reports its centre
  /// right away; Central Europe only until then.
  double _zoom = 3;
  LatLng _center = const LatLng(50, 10);
  GeoRegion? _detected;

  /// Where the region was last re-detected (see [_onGlobeMoved]).
  ({double lat, double lng})? _detectedAt;
  double _detectedZoom = 3;

  /// The globe is still flying to a search result. The tick waits for it to
  /// land: the centre is the picked spot, and mid-flight it is somewhere on
  /// the way.
  bool _flying = false;

  Future<void> _init() async {
    await GeoRegions.instance.load();
    _detect();
    await _loadMyMap();
  }

  /// Camera callbacks can arrive while laying out, and calling `setState`
  /// then throws "setState() called during build". Defer if so.
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

  /// `_center`/`_zoom` are read on confirm, so keep them current on every
  /// frame — but as plain fields, WITHOUT setState. Reverse-geocoding the
  /// centre (`_detect`) every frame is what once froze this picker, so do it
  /// only when the view has actually moved: a ~0.1 zoom step or the centre
  /// moving ~0.12° (which can cross into a new region).
  void _onGlobeMoved() {
    final c = _globeController.center;
    final zoom = _globeController.zoom;
    if (!zoom.isFinite) return;
    _center = LatLng(c.lat, c.lng);
    _zoom = zoom;
    _clearBorrowedName();
    final flying = _globeController.flying;
    if (flying != _flying) _safeSetState(() => _flying = flying);

    final last = _detectedAt;
    final zoomStep = (zoom - _detectedZoom).abs() >= 0.1;
    final movedFar =
        last == null ||
        (c.lat - last.lat).abs() >= 0.12 ||
        (c.lng - last.lng).abs() >= 0.12;
    if (!zoomStep && !movedFar) return;
    _detectedAt = c;
    _detectedZoom = zoom;
    _detect();
  }

  /// Whether the tick does anything. Deliberately NOT gated on the name: a
  /// disabled tick can't explain itself, so it stays tappable and [_confirm]
  /// turns the name field red instead. It does wait out a flight, though.
  bool get _canConfirm => _detected != null && !_flying;

  /// Whether the tick looks ready — everything needed has been filled in.
  bool get _isComplete =>
      _canConfirm && _placeController.text.trim().isNotEmpty;

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
    // Resolve from the live centre, not the throttled `_detected`: detection
    // now updates in steps, so near a border `_detected` could be a beat stale.
    // The confirmed region must match the exact pin position.
    final region =
        GeoRegions.instance.regionAt(_center.longitude, _center.latitude) ??
        _detected;
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
              // Your own travel map on the globe: shaded regions, a pin for
              // every place you have posted from, country / province names.
              Positioned.fill(
                child: GlobeView(
                  look: GlobeLook.picker,
                  visitedCounts: _myCounts,
                  points: _myPoints,
                  controller: _globeController,
                  showButtons: false,
                  borderRadius: 0,
                  onPinTap: _repick,
                ),
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
                    _MapButton(
                      icon: Icons.add,
                      onTap: () => _globeController.zoomBy(1),
                    ),
                    const SizedBox(height: 10),
                    _MapButton(
                      icon: Icons.remove,
                      onTap: () => _globeController.zoomBy(-1),
                    ),
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
                        region.localizedDisplayName(
                          Localizations.localeOf(context).languageCode,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      region.localizedCountryName(
                        Localizations.localeOf(context).languageCode,
                      ),
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

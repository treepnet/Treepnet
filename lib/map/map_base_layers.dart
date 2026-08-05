import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:treepnet/map/geo_regions.dart';

/// {@template map_base_layers}
/// The world's base geometry as `flutter_map` polygons, built **once** per app
/// session and shared by every map (the profile travel map and the location
/// picker).
///
/// Converting ~8000 GeoJSON rings into [Polygon]s takes a noticeable moment, so
/// rebuilding it each time a map opened showed a long spinner. Caching it here
/// means only the first map pays that cost.
/// {@endtemplate}
class MapBaseLayers {
  MapBaseLayers._();

  /// The shared instance.
  static final MapBaseLayers instance = MapBaseLayers._();

  /// Land fill of every country (also the map's dark landmass).
  static const landColor = Color(0xFF0B0D0F);

  /// Faint internal province divisions.
  static const provinceBorderColor = Color(0x40FFFFFF);

  /// Bright international borders.
  static const countryBorderColor = Color(0xFFFFFFFF);

  /// Ocean / background behind the land.
  static const oceanColor = Color(0xFF2B2F33);

  /// Country shapes filled dark with a bright outline — cheap, drawn at every
  /// zoom.
  final List<Polygon> countryOutlines = [];

  /// Province outlines only (no fill) — drawn once zoomed in, culled by
  /// `flutter_map` to the viewport.
  final List<Polygon> provinceBorders = [];

  bool _built = false;
  Future<void>? _building;

  /// Whether the polygons are ready.
  bool get isBuilt => _built;

  /// Loads the GeoJSON and builds the polygons exactly once. Safe to await from
  /// several maps concurrently.
  Future<void> build() {
    if (_built) return Future.value();
    return _building ??= _build();
  }

  /// Antarctica is never a travel destination here and its ice sheet dominates
  /// the bottom of the map, so it is dropped entirely. Its northernmost point
  /// (the peninsula) sits near 63°S, while the southern tip of South America
  /// reaches only ~56°S — so "wholly south of 58°S" cleanly separates them.
  static bool _isAntarctic(List<Offset> ring) {
    var maxLat = -90.0;
    for (final p in ring) {
      if (p.dy > maxLat) maxLat = p.dy;
    }
    return maxLat < -58;
  }

  Future<void> _build() async {
    await GeoRegions.instance.load();
    final geo = GeoRegions.instance;

    for (final ring in geo.countryRings) {
      if (ring.length < 3 || _isAntarctic(ring)) continue;
      countryOutlines.add(
        Polygon(
          points: [for (final p in ring) LatLng(p.dy, p.dx)],
          color: landColor,
          borderColor: countryBorderColor,
          borderStrokeWidth: 1.1,
        ),
      );
    }
    for (final region in geo.allRegions) {
      for (final ring in region.rings) {
        if (ring.length < 3 || _isAntarctic(ring)) continue;
        provinceBorders.add(
          Polygon(
            points: [for (final p in ring) LatLng(p.dy, p.dx)],
            borderColor: provinceBorderColor,
            borderStrokeWidth: 0.6,
          ),
        );
      }
    }
    _built = true;
  }
}

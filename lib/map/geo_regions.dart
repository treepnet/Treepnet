import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// A single administrative region (ISO 3166-2), e.g. Istanbul (`TR-34`).
///
/// Geometry is parsed lazily (only when [rings] is first read) so loading the
/// full world index stays cheap — the picker never touches geometry, and the
/// map only materializes the handful of visited regions.
class GeoRegion {
  GeoRegion({
    required this.iso,
    required this.name,
    required this.countryCode,
    required this.countryName,
    required Map<String, dynamic> geometry,
  }) : _geometry = geometry;

  /// ISO 3166-2 code, e.g. `TR-34`.
  final String iso;

  /// Display name of the region, e.g. `Istanbul`.
  final String name;

  /// ISO 3166-1 alpha-2 country code, e.g. `TR`.
  final String countryCode;

  /// Display name of the country, e.g. `Turkey`.
  final String countryName;

  /// Whether this region shares its [name] with a smaller one in the same
  /// country — a province named after its capital, like Tashkent or Moscow.
  /// Set once at load time by [GeoRegions._markNameClashes].
  bool sharesNameWithCity = false;

  /// What to print on the map. Disambiguated only where it has to be, so the
  /// city keeps the bare name and the province around it says "Region".
  String get displayName => sharesNameWithCity ? '$name Region' : name;

  final Map<String, dynamic> _geometry;
  List<List<Offset>>? _rings;
  Rect? _bounds;
  Offset? _centroid;

  /// Polygon rings in raw `lng`/`lat` coordinates, stored as `Offset(lng, lat)`.
  /// Includes outer rings and holes; render with an even-odd fill rule.
  List<List<Offset>> get rings => _rings ??= _parseGeometry(_geometry);

  /// Bounding box of the region in lng/lat (`Rect.fromLTRB(minLng, minLat,
  /// maxLng, maxLat)`). Used for viewport culling and label sizing.
  Rect get lngLatBounds => _bounds ??= _computeBounds();

  /// Approximate label anchor (centroid of the largest ring), in lng/lat.
  Offset get centroidLngLat => _centroid ??= _computeCentroid();

  Rect _computeBounds() {
    var minX = 180.0;
    var minY = 90.0;
    var maxX = -180.0;
    var maxY = -90.0;
    for (final ring in rings) {
      for (final p in ring) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
    }
    if (minX > maxX) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _computeCentroid() {
    if (rings.isEmpty) return Offset.zero;
    // The ring with the most *area*, not the most points: a craggy little
    // island can easily out-vertex the mainland, which parked labels like
    // France's out over its neighbours.
    List<Offset>? big;
    var bigArea = -1.0;
    for (final ring in rings) {
      if (ring.length < 3) continue;
      var sum = 0.0;
      for (var i = 0; i < ring.length; i++) {
        final p = ring[i];
        final q = ring[(i + 1) % ring.length];
        sum += p.dx * q.dy - q.dx * p.dy;
      }
      final area = sum.abs() / 2;
      if (area > bigArea) {
        bigArea = area;
        big = ring;
      }
    }
    big ??= rings.reduce((a, b) => a.length >= b.length ? a : b);
    if (big.isEmpty) return Offset.zero;
    var sx = 0.0;
    var sy = 0.0;
    for (final p in big) {
      sx += p.dx;
      sy += p.dy;
    }
    return Offset(sx / big.length, sy / big.length);
  }

  double? _ringArea;

  /// Total land area (shoelace, summed over every ring) in degrees². A far
  /// better size proxy than the bounding box for regions made of many pieces —
  /// used to anchor and size country labels.
  double get landArea => _ringArea ??= _computeLandArea();

  double _computeLandArea() {
    var total = 0.0;
    for (final ring in rings) {
      if (ring.length < 3) continue;
      var sum = 0.0;
      for (var i = 0; i < ring.length; i++) {
        final p = ring[i];
        final q = ring[(i + 1) % ring.length];
        sum += p.dx * q.dy - q.dx * p.dy;
      }
      total += sum.abs() / 2;
    }
    return total;
  }

  static List<List<Offset>> _parseGeometry(Map<String, dynamic> geometry) {
    final type = geometry['type'];
    final coords = geometry['coordinates'] as List;
    final rings = <List<Offset>>[];
    if (type == 'Polygon') {
      for (final ring in coords) {
        rings.add(parseRing(ring as List<dynamic>));
      }
    } else if (type == 'MultiPolygon') {
      for (final polygon in coords) {
        for (final ring in polygon as List) {
          rings.add(parseRing(ring as List<dynamic>));
        }
      }
    }
    return rings;
  }

  /// Parses a GeoJSON ring into `Offset(lng, lat)` points.
  static List<Offset> parseRing(List<dynamic> ring) => [
    for (final pt in ring)
      Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble()),
  ];
}

/// A country grouping its [regions].
class GeoCountry {
  GeoCountry({
    required this.code,
    required this.name,
    required this.regions,
  });

  final String code;
  final String name;
  final List<GeoRegion> regions;
}

/// A country label for the map: its display [name], [center] (lng/lat anchor)
/// and [spanDeg] (bounding-box width in degrees, used to decide at which zoom
/// the label appears — wide countries show first).
class CountryLabel {
  const CountryLabel({
    required this.name,
    required this.center,
    required this.spanDeg,
  });

  final String name;
  final Offset center;
  final double spanDeg;
}

/// {@template geo_regions}
/// Loads and indexes the bundled world GeoJSON assets, exposing data for both
/// the location picker (countries → regions) and the travel map (a light
/// country base + region polygons by ISO). Parsed once and cached.
/// {@endtemplate}
class GeoRegions {
  GeoRegions._();

  static final GeoRegions instance = GeoRegions._();

  static const _assetPath = 'assets/geo/world_admin1.min.json';
  static const _basePath = 'assets/geo/world_countries.min.json';

  bool _loaded = false;
  Future<void>? _loading;

  final Map<String, GeoRegion> _byIso = {};
  final List<GeoCountry> _countries = [];

  /// Country outline rings (lng/lat as `Offset(lng, lat)`) for the map base —
  /// a light ~288-ring landmass, far cheaper to paint than every province.
  final List<List<Offset>> _countryRings = [];

  /// The light country-outline base rings for the travel map.
  List<List<Offset>> get countryRings => _countryRings;

  /// Country labels (name + anchor + span) for the zoom-dependent map labels.
  final List<CountryLabel> _countryLabels = [];
  List<CountryLabel> get countryLabels => _countryLabels;

  // --- Projected-geometry cache (screen-space paths for crisp vector zoom) ---
  final Map<String, Path> _projPaths = {};
  final Map<String, Rect> _projBounds = {};
  final List<(Path, Rect)> _projCountry = [];
  double _projKey = -1;

  /// Province paths projected into the current canvas space (by [iso]).
  Map<String, Path> get projPaths => _projPaths;

  /// Screen-space bounding boxes of [projPaths] (by [iso]).
  Map<String, Rect> get projBounds => _projBounds;

  /// Country outline paths (path + bounds) projected into canvas space.
  List<(Path, Rect)> get projCountry => _projCountry;

  /// Projects every province + country ring into the canvas space defined by
  /// the given fit (rebuilds only when that fit changes). Lets the painter blit
  /// crisp vector paths at any zoom without re-projecting each frame.
  void ensureProjected(double offX, double offY, double drawW, double drawH) {
    if (_projKey == drawW && _projPaths.isNotEmpty) return;
    _projKey = drawW;
    _projPaths.clear();
    _projBounds.clear();
    _projCountry.clear();

    Offset pr(Offset ll) => Offset(
      offX + (ll.dx + 180) / 360 * drawW,
      offY + (90 - ll.dy) / 180 * drawH,
    );

    void build(Path path, List<Offset> ring) {
      if (ring.isEmpty) return;
      final f = pr(ring.first);
      path.moveTo(f.dx, f.dy);
      var prevLng = ring.first.dx;
      for (var i = 1; i < ring.length; i++) {
        final lng = ring[i].dx;
        final p = pr(ring[i]);
        // A >180° longitude jump means the ring crosses the antimeridian; a
        // straight line would streak across the whole map, so lift the pen.
        if ((lng - prevLng).abs() > 180) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
        prevLng = lng;
      }
      if ((ring.last.dx - ring.first.dx).abs() <= 180) path.close();
    }

    for (final region in _byIso.values) {
      final path = Path()..fillType = PathFillType.evenOdd;
      for (final ring in region.rings) {
        build(path, ring);
      }
      _projPaths[region.iso] = path;
      _projBounds[region.iso] = path.getBounds();
    }
    for (final ring in _countryRings) {
      final path = Path();
      build(path, ring);
      _projCountry.add((path, path.getBounds()));
    }
  }

  /// Whether the data has finished loading.
  bool get isLoaded => _loaded;

  /// All countries, sorted by name.
  List<GeoCountry> get countries => _countries;

  /// Every region across all countries.
  Iterable<GeoRegion> get allRegions => _byIso.values;

  /// Returns the region for an ISO 3166-2 [iso] code, or null.
  GeoRegion? regionByIso(String? iso) => iso == null ? null : _byIso[iso];

  /// Reverse-geocodes a point: the admin-1 region whose polygon contains
  /// [lng]/[lat] (bounding-box pre-filter, then even-odd ray casting), or null
  /// over ocean / uncovered areas.
  GeoRegion? regionAt(double lng, double lat) {
    final pt = Offset(lng, lat);
    for (final region in _byIso.values) {
      if (!region.lngLatBounds.contains(pt)) continue;
      if (_containsPoint(region.rings, lng, lat)) return region;
    }
    return null;
  }

  static bool _containsPoint(List<List<Offset>> rings, double x, double y) {
    var inside = false;
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final xi = ring[i].dx;
        final yi = ring[i].dy;
        final xj = ring[j].dx;
        final yj = ring[j].dy;
        final intersect = ((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
        if (intersect) inside = !inside;
      }
    }
    return inside;
  }

  /// Reference canvas the base map is recorded in (equirectangular 2:1).
  static const baseWidth = 3000.0;
  static const baseHeight = 1500.0;

  Picture? _basePicture;
  Image? _baseImage;

  /// The rasterized base map, or null until [buildBaseImage] completes.
  Image? get baseImageOrNull => _baseImage;

  /// Rasterizes the base [Picture] into a cached [Image] once. Painting a
  /// prebuilt image (a single GPU blit) keeps manual pan/zoom smooth — far
  /// cheaper than re-rasterizing ~8000 province/country paths every frame.
  Future<Image> buildBaseImage() async {
    if (_baseImage != null) return _baseImage!;
    _baseImage = await basePicture().toImage(
      baseWidth.toInt(),
      baseHeight.toInt(),
    );
    return _baseImage!;
  }

  /// A cached vector [Picture] of the whole world drawn once: every admin-1
  /// province filled near-black with thin white borders, plus admin-0 country
  /// outlines. Rendered as a single [Picture] so the ~4000+ polygons are built
  /// once and then cheaply blitted (and stay crisp when zoomed).
  Picture basePicture() {
    if (_basePicture != null) return _basePicture!;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    Offset proj(Offset ll) => Offset(
      (ll.dx + 180) / 360 * baseWidth,
      (90 - ll.dy) / 180 * baseHeight,
    );

    final landPaint = Paint()..color = const Color(0xFF0B0D0F);
    // Province (internal) borders: thin & dim.
    final provinceBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.25
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x59FFFFFF);
    // Country (international) borders: thicker & bright.
    final countryBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFFFFF);

    void addRings(Path path, List<List<Offset>> rings) {
      for (final ring in rings) {
        if (ring.isEmpty) continue;
        final f = proj(ring.first);
        path.moveTo(f.dx, f.dy);
        var prevLng = ring.first.dx;
        for (var i = 1; i < ring.length; i++) {
          final lng = ring[i].dx;
          final p = proj(ring[i]);
          // Break the line across an antimeridian (>180° longitude) jump so it
          // doesn't streak all the way across the map.
          if ((lng - prevLng).abs() > 180) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
          prevLng = lng;
        }
        if ((ring.last.dx - ring.first.dx).abs() <= 180) path.close();
      }
    }

    // 1) Fill + thin province borders, each province on its own so the 10m
    // borders stay crisp (even-odd cuts out enclaves; no winding artifacts).
    for (final region in _byIso.values) {
      final path = Path()..fillType = PathFillType.evenOdd;
      addRings(path, region.rings);
      canvas
        ..drawPath(path, landPaint)
        ..drawPath(path, provinceBorder);
    }

    // 2) Bright, thicker country outlines on top (distinct from provinces).
    final countryPath = Path();
    addRings(countryPath, _countryRings);
    canvas.drawPath(countryPath, countryBorder);

    _basePicture = recorder.endRecording();
    return _basePicture!;
  }

  /// Parses the bundled GeoJSON exactly once.
  /// Always hands back the *same* future. Returning a fresh `Future.value()`
  /// once loaded made every `FutureBuilder` on it flip back to "waiting" on
  /// each rebuild, tearing down and re-creating its subtree — which reset the
  /// travel map's camera on every tap.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    // Light country base for the map landmass (parsed eagerly — only ~288).
    final baseRaw = await rootBundle.loadString(_basePath);
    final baseData = json.decode(baseRaw) as Map<String, dynamic>;
    for (final ring in baseData['rings'] as List) {
      _countryRings.add(GeoRegion.parseRing(ring as List<dynamic>));
    }

    // Admin-1 index — metadata now, geometry lazily per region.
    final raw = await rootBundle.loadString(_assetPath);
    final data = json.decode(raw) as Map<String, dynamic>;
    final features = data['features'] as List;

    final byCountry = <String, GeoCountry>{};
    for (final feature in features) {
      final props = (feature as Map)['properties'] as Map;
      final iso = props['iso'] as String?;
      if (iso == null || iso.isEmpty) continue;
      final countryCode = (props['cc'] as String?) ?? '';
      final countryName = (props['admin'] as String?) ?? countryCode;
      final name = (props['name'] as String?) ?? iso;
      final geometry = feature['geometry'] as Map<String, dynamic>;

      final region = GeoRegion(
        iso: iso,
        name: name,
        countryCode: countryCode,
        countryName: countryName,
        geometry: geometry,
      );
      _byIso[iso] = region;

      final country = byCountry.putIfAbsent(
        countryName,
        () => GeoCountry(code: countryCode, name: countryName, regions: []),
      );
      country.regions.add(region);
    }

    for (final country in byCountry.values) {
      country.regions.sort((a, b) => a.name.compareTo(b.name));
    }
    _countries
      ..clear()
      ..addAll(byCountry.values)
      ..sort((a, b) => a.name.compareTo(b.name));

    _markNameClashes();
    _buildCountryLabels();

    _loaded = true;
  }

  /// Flags provinces that share a name with a city-sized region in the same
  /// country, so the map can tell "Tashkent" from "Tashkent Region".
  ///
  /// Matches on distinct ISO codes, not just names: several countries store one
  /// region as a handful of separate features under a single code (Madagascar,
  /// Bosnia, Ireland), and those are the same place — labelling one of them
  /// "… Region" would invent a distinction that does not exist.
  void _markNameClashes() {
    for (final country in _countries) {
      final byName = <String, List<GeoRegion>>{};
      for (final region in country.regions) {
        byName.putIfAbsent(region.name.trim().toLowerCase(), () => []).add(
          region,
        );
      }
      for (final sharing in byName.values) {
        if (sharing.length < 2) continue;
        // Sum per ISO first — a region split across features must count once.
        final areaByIso = <String, double>{};
        for (final region in sharing) {
          areaByIso[region.iso] =
              (areaByIso[region.iso] ?? 0) + region.landArea;
        }
        if (areaByIso.length < 2) continue;
        // The smallest is the city and keeps the bare name; everything larger
        // around it gets the suffix.
        final city = areaByIso.entries
            .reduce((a, b) => a.value <= b.value ? a : b)
            .key;
        final smallest = areaByIso[city]!;
        final largest = areaByIso.values.reduce(math.max);
        // Only when one really is a city inside the other. Same-sized pairs are
        // two neighbours that happen to share a name (Altai Republic and Altai
        // Krai, the two halves of Tobago) — neither is "the region".
        if (smallest <= 0 || largest < smallest * 3) continue;
        for (final region in sharing) {
          if (region.iso != city) region.sharesNameWithCity = true;
        }
      }
    }
  }

  /// How far apart (degrees) two provinces' bounding boxes may sit and still
  /// count as the same landmass. Neighbours share a border, so their boxes
  /// touch or overlap and the gap is 0; 1° only forgives coastline slack.
  static const _landmassGapDeg = 1.0;

  /// Empty gap between two boxes — 0 when they touch or overlap.
  static double _boxGap(Rect a, Rect b) {
    final gx = math.max(0.0, math.max(a.left - b.right, b.left - a.right));
    final gy = math.max(0.0, math.max(a.top - b.bottom, b.top - a.bottom));
    return math.max(gx, gy);
  }

  /// Splits a country's provinces into landmasses and returns the biggest one
  /// by land area, so a label is anchored on the mainland.
  ///
  /// Averaging over ALL of a country's provinces is what put "FRANCE" out over
  /// Portugal: French Guiana alone is a sixth of the country's land, and with
  /// Réunion and the Caribbean départements pulling too, the mean landed in the
  /// Atlantic. The same guard keeps the USA off Alaska and Spain off the
  /// Canaries.
  ///
  /// Linking on box gaps rather than distance between centres matters for
  /// countries built from huge provinces: Siberia's neighbours can have
  /// centres a thousand kilometres apart while still sharing a border, and
  /// measuring centres tore Russia in half at the Yenisei.
  List<GeoRegion> _mainLandmass(List<GeoRegion> regions) {
    final pool = regions.toList();
    var best = const <GeoRegion>[];
    var bestArea = -1.0;

    while (pool.isNotEmpty) {
      // Flood-fill outward from one province: anything touching the growing
      // group joins it, which chains along a coastline or a border but never
      // jumps an ocean.
      final cluster = <GeoRegion>[pool.removeLast()];
      for (var i = 0; i < cluster.length; i++) {
        final box = cluster[i].lngLatBounds;
        for (var j = pool.length - 1; j >= 0; j--) {
          if (_boxGap(box, pool[j].lngLatBounds) <= _landmassGapDeg) {
            cluster.add(pool.removeAt(j));
          }
        }
      }
      final area = cluster.fold(0.0, (sum, r) => sum + r.landArea);
      if (area > bestArea) {
        bestArea = area;
        best = cluster;
      }
    }
    return best;
  }

  /// Builds one label per country, anchored on its main landmass. [spanDeg] is
  /// derived from the summed area of that landmass's provinces (`sqrt`), NOT
  /// the overall bounding box — so scattered island territories don't inflate
  /// the size and make a small country's label appear at world zoom.
  void _buildCountryLabels() {
    _countryLabels.clear();
    for (final country in _countries) {
      final usable = country.regions
          .where((r) => r.lngLatBounds != Rect.zero && r.landArea > 0)
          .toList();
      if (usable.isEmpty) continue;
      final mainland = _mainLandmass(usable);
      if (mainland.isEmpty) continue;

      var totalArea = 0.0;
      // Area-weighted centroid, so big provinces decide where the label sits
      // and slivers barely count.
      var cx = 0.0;
      var cy = 0.0;
      var wsum = 0.0;
      GeoRegion? biggest;
      var biggestArea = -1.0;
      for (final region in mainland) {
        final b = region.lngLatBounds;
        final c = region.centroidLngLat;
        // Degrees² badly overstate area near the poles, which made e.g. the
        // USA's label far too wide. Scale by cos(latitude) so both the anchor
        // weight and the size proxy track real ground area.
        final cosLat = math.cos(c.dy * math.pi / 180).abs().clamp(0.05, 1.0);
        // A bounding box wildly overstates regions made of scattered islands
        // (Kiribati spans the Pacific), which showed their label at world zoom.
        // Cap the box by a generous multiple of the real land area: extreme
        // cases get cut, ordinary ones don't.
        final land = region.landArea;
        totalArea += math.min(b.width * b.height, land * 8) * cosLat;
        final w = land * cosLat;
        if (w <= 0) continue;
        cx += c.dx * w;
        cy += c.dy * w;
        wsum += w;
        if (land > biggestArea) {
          biggestArea = land;
          biggest = region;
        }
      }
      if (wsum <= 0 || totalArea <= 0) continue;

      var center = Offset(cx / wsum, cy / wsum);
      // A crescent- or horseshoe-shaped country (Croatia, Vietnam) can have its
      // average fall outside its own borders. Drop the label onto the largest
      // province instead, so it always reads as being on that country.
      final onLand = mainland.any(
        (r) => _containsPoint(r.rings, center.dx, center.dy),
      );
      if (!onLand) center = (biggest ?? mainland.first).centroidLngLat;

      // Antarctica's polygons aren't drawn (see MapBaseLayers), so it must not
      // get a label floating over empty ocean either.
      if (center.dy < -58) continue;
      _countryLabels.add(
        CountryLabel(
          name: country.name,
          center: center,
          spanDeg: math.sqrt(totalArea),
        ),
      );
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/map_base_layers.dart';
import 'package:treepnet/map/travel_map.dart';

/// The travel map drawn as a rotatable 3D globe.
///
/// Orthographic projection, painted by hand: every ring is converted once to
/// unit vectors on the sphere, so a frame is a couple of dot products per point
/// — no trig. The far side of a filled ring is walked around the rim, which
/// keeps it closed. Each layer is decimated to a few levels of detail, picked
/// by the on-screen scale, and rings outside the visible cap are culled.
///
/// The name and border thresholds mirror [TravelMap], so the globe shows the
/// same things at the same scale: province borders, then country and province
/// names. On the travel map a region's pins merge into one until zoomed in.
///
/// The globe claims every pointer that lands on it, so dragging it never
/// scrolls the page underneath.
///
/// One globe stands in for each flat map — the profile map and onboarding
/// ([TravelMap], [GlobeLook.travelMap]) and the post location picker
/// ([GlobeLook.picker]) — and copies the rules of the one it replaces.
class GlobeView extends StatefulWidget {
  const GlobeView({
    required this.visitedCounts,
    this.points = const [],
    this.look = GlobeLook.travelMap,
    this.onTargetTap,
    this.tapAnyRegion = false,
    this.onPinTap,
    this.focusBounds,
    this.focusToken = 0,
    this.focusMaxZoom = 6,
    this.initialCenter,
    this.initialZoom = 3,
    this.controller,
    this.autoRotate = false,
    this.showButtons = true,
    this.borderRadius = 16,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// ISO 3166-2 region code -> post count (same input as [TravelMap]).
  final Map<String, int> visitedCounts;

  /// Post / story pins.
  final List<({double lat, double lng, String? name})> points;

  /// Which flat map this globe replaces.
  final GlobeLook look;

  /// [GlobeLook.travelMap]: called for a tap on a pin — or on any region when
  /// [tapAnyRegion] (onboarding), as on [TravelMap].
  final ValueSetter<TravelMapTarget>? onTargetTap;

  /// Report taps on any region, visited or not ([TravelMap.tapAnyRegion]).
  final bool tapAnyRegion;

  /// [GlobeLook.picker]: called for a tap on one of the pins.
  final ValueSetter<({double lat, double lng, String? name})>? onPinTap;

  /// Where to look: applied on first load and whenever [focusToken] changes
  /// ([TravelMap.focusBounds]).
  final LatLngBounds? focusBounds;
  final int focusToken;

  /// Ceiling for a [focusBounds] fit, as a flat-map zoom level.
  final double focusMaxZoom;

  /// The opening centre and flat-map zoom level, when not [focusBounds].
  /// Without either, the globe opens whole, over the user's travels.
  final ({double lat, double lng})? initialCenter;
  final double initialZoom;

  /// Reads where the globe is looking and moves it (the location picker).
  final GlobeController? controller;

  /// Spin gently until the first touch.
  final bool autoRotate;

  /// The +, − and "my location" buttons ([TravelMap] has them; the picker
  /// draws its own).
  final bool showButtons;

  final double borderRadius;

  /// Parts of the globe's area that something else covers (the profile's
  /// pinned bar and tabs sit over the top of its tab). The globe is sized
  /// and centred in what is left, so nothing it shows hides underneath.
  final EdgeInsets padding;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

/// Which flat map a [GlobeView] stands in for. They draw pins and names a
/// little differently, and the globe copies whichever one it replaces.
enum GlobeLook {
  /// [TravelMap]: the profile map and onboarding. 26 px pins that dim once
  /// opened, names drawn over the pins.
  travelMap,

  /// The post location picker: 22 px pins drawn over the names.
  picker,
}

/// Drives a [GlobeView] from outside and reports where it is looking. Listeners
/// hear every camera move.
class GlobeController extends ChangeNotifier {
  _GlobeViewState? _view;

  /// The point under the centre of the globe.
  ({double lat, double lng}) get center {
    final cam = _view?._cam;
    return cam == null ? (lat: 0, lng: 0) : (lat: cam.lat, lng: cam.lon);
  }

  /// The current scale, as a flat-map zoom level.
  double get zoom => _view?._flatZoom ?? 3;

  /// Whether the globe is flying somewhere (a search result, a double tap):
  /// [center] is still on its way. Listeners hear when it lands.
  bool get flying => _view?._panTarget != null;

  /// Looks at [lat]/[lng], optionally at flat-map [zoom]. Instant unless
  /// [animate] — an instant move reaches listeners before this returns.
  void moveTo(double lat, double lng, {double? zoom, bool animate = false}) =>
      _view?._moveTo(lat, lng, flatZoom: zoom, animate: animate);

  /// Zooms by [levels] flat-map zoom levels (each one doubles the scale).
  void zoomBy(double levels) =>
      _view?._zoomBy(math.pow(2, levels).toDouble());
}

const double _deg = math.pi / 180;
/// The furthest zoom-out: the whole globe at its opening size — further out
/// it only shrinks into a small ball.
const double _minZoom = 1;

/// At zoom 1 the globe spans this share of the visible area's shorter side,
/// leaving a margin for its glow.
const double _globeFill = 0.9;

/// Pixels per degree at a flat-map (Web Mercator) zoom level: 256 px tiles,
/// doubling each level.
double _ppdForFlat(double zoom) => 256 * math.pow(2, zoom) / 360;

/// Zoom-in ceiling, as on both flat maps (zoom 15).
const double _maxFlatZoom = 15;

// Scale (pixels per degree at the globe's centre) at which each layer appears.
// These are the flat map's zoom 3 / 4.5 / 5 thresholds, so both maps read alike.
const double _provincePpd = 5;

/// The flat map's furthest zoom-out (zoom 3).
const double _flatMinPpd = 5.7;
const double _provinceNamePpd = 16;

// Pin levels, counted in "+" taps from the whole globe (zoom 1; each tap
// doubles it): until the 4th tap a region's pins merge into one pin, from the
// 4th every pin shows, from the 5th with its name. The same on every globe.
const double _pinsSplitZoom = 16;
const double _pinNamesZoom = 32;

/// Whether [zoom] has reached [level] (a pinch can stop a hair short).
bool _atZoom(double zoom, double level) => zoom >= level * 0.999;

// Where each flat map's pin marker puts the icon and the name relative to the
// pin's point. TravelMap: a 96×62 marker centred on it, 24 px bottom padding,
// 26 px icon over the name — icon top 31 px above, name top 5 px above. The
// picker: 96×58, 22 px padding, 22 px icon — 29 and 7 px above.
const double _pinIconTop = 31;
const double _pinNameTop = 5;
const double _pickerPinIconTop = 29;
const double _pickerPinNameTop = 7;

/// The part of a [size] panel left visible by [padding] (never negative).
Rect _visibleRect(Size size, EdgeInsets padding) {
  final rect = padding.deflateRect(Offset.zero & size);
  return rect.width <= 0 || rect.height <= 0 ? Offset.zero & size : rect;
}

/// Decimation steps (degrees) for the levels of detail, coarsest first.
const _steps = [0.8, 0.32, 0.13, 0.05, 0.02, 0.0];

/// The coarsest level whose segments stay under ~2.5 px at [ppd].
double _stepFor(double ppd) {
  for (final s in _steps) {
    if (s * ppd <= 2.5) return s;
  }
  return 0;
}

/// Where the globe is looking. The painter listens to it, so a rotation frame
/// repaints the globe without rebuilding any widgets.
class _Camera extends ChangeNotifier {
  double lon = 0;
  double lat = 0;
  double zoom = 1;

  void changed() => notifyListeners();
}

class _GlobeViewState extends State<GlobeView>
    with TickerProviderStateMixin {
  final _cam = _Camera();
  /// Created on first use: a globe that never moves on its own never needs
  /// one — and creating it in [dispose] would look up an ancestor that is
  /// already gone.
  Ticker? _ticker;

  /// How far each region's pins have spread out of its merged pin: 0 merged,
  /// 1 every pin in its own place. Eased between the two when the zoom
  /// crosses [_pinsSplitZoom], so pins slide out instead of popping up.
  late final AnimationController _split = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  bool _splitOpen = false;
  Duration _lastTick = Duration.zero;
  Size _size = Size.zero;

  // Motion.
  late bool _autoRotate = widget.autoRotate;
  double _vLon = 0; // degrees per second
  double _vLat = 0;
  double? _zoomTarget;
  ({double lon, double lat})? _panTarget;

  // Pointers on the globe — handled by hand, see [build].
  final _pointers = <int, Offset>{};
  VelocityTracker? _velocity;
  double _pinchDistance = 0;
  double _pinchZoom = 1;
  Offset? _downAt;
  Duration _downTime = Duration.zero;
  bool _tapCandidate = false;
  Offset? _lastTapAt;
  Duration _lastTapTime = Duration.zero;
  Timer? _tapTimer;

  _GlobeScene? _scene;

  /// The opening view, once the globe has a size to frame it in; the "my
  /// location" button returns here (except on the profile, see [_reset]).
  ({double lon, double lat, double zoom})? _initialView;

  @override
  void initState() {
    super.initState();
    final c = _homeCenter();
    _cam
      ..lon = c.lon
      ..lat = c.lat
      ..addListener(_notifyController);
    widget.controller?._view = this;
    _cam.addListener(_syncSplit);
    if (_autoRotate) _ensureTicking();
    if (widget.look == GlobeLook.travelMap) unawaited(_loadSeenPoints());
    // Putting the province layer on the sphere takes a moment. Do it while the
    // globe idles rather than on the user's first zoom.
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      final geo = GeoRegions.instance;
      if (!mounted || !geo.isLoaded) return;
      final data = _GlobeData.of(geo);
      data.provinces
        ..at(_steps[0])
        ..at(_steps[1]);
      data.regionLabels.length;
    });
  }

  @override
  void didUpdateWidget(covariant GlobeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      if (identical(oldWidget.controller?._view, this)) {
        oldWidget.controller?._view = null;
      }
      widget.controller?._view = this;
    }
    // A new focus request flies there ([TravelMap.focusToken]).
    final focus = widget.focusBounds;
    if (focus != null &&
        widget.focusToken != oldWidget.focusToken &&
        !_view.isEmpty) {
      final v = _fit(focus);
      _stopMotion();
      _panTarget = (lon: v.lon, lat: v.lat);
      _zoomTarget = v.zoom;
      _ensureTicking();
    }
    // The travel data streams in after the globe is built. Until the user
    // touches it, turn to face their travels once it arrives.
    final hadData =
        oldWidget.visitedCounts.isNotEmpty || oldWidget.points.isNotEmpty;
    final hasData = widget.visitedCounts.isNotEmpty || widget.points.isNotEmpty;
    if (_autoRotate && !hadData && hasData) {
      _panTarget = _homeCenter();
      _ensureTicking();
    }
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    if (identical(widget.controller?._view, this)) {
      widget.controller?._view = null;
    }
    _ticker?.dispose();
    _split.dispose();
    _cam.dispose();
    super.dispose();
  }

  void _notifyController() => widget.controller?.notifyListeners();

  /// Spreads the pins out (or gathers them in) as the zoom crosses
  /// [_pinsSplitZoom].
  void _syncSplit() {
    final open = _atZoom(_cam.zoom, _pinsSplitZoom);
    if (open == _splitOpen) return;
    _splitOpen = open;
    if (open) {
      unawaited(_split.forward());
    } else {
      unawaited(_split.reverse());
    }
  }

  /// Sets the opening view the first time the globe has a size — framing
  /// needs the size. Called from layout, so it changes fields only.
  void _applyInitialView() {
    if (_initialView != null || _view.isEmpty) return;
    // Listeners (the picker reads the centre as its spot) hear where the
    // globe opened once this frame is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyController();
    });
    final focus = widget.focusBounds;
    final center = widget.initialCenter;
    if (focus != null) {
      _initialView = _fit(focus);
    } else if (center != null) {
      _initialView = (
        lon: center.lng,
        lat: center.lat,
        zoom: _clampZoom(_zoomForFlat(widget.initialZoom)),
      );
    } else {
      _initialView = (lon: _cam.lon, lat: _cam.lat, zoom: _cam.zoom);
      return;
    }
    final v = _initialView!;
    _cam
      ..lon = v.lon
      ..lat = v.lat
      ..zoom = v.zoom;
  }

  /// The view that frames [bounds] with a 16 px margin, no closer than
  /// [GlobeView.focusMaxZoom] — [TravelMap]'s fit.
  ({double lon, double lat, double zoom}) _fit(LatLngBounds bounds) {
    final lat = (bounds.north + bounds.south) / 2;
    final lng = (bounds.east + bounds.west) / 2;
    final w = math.max(1e-6, (bounds.east - bounds.west) * math.cos(lat * _deg));
    final h = math.max(1e-6, bounds.north - bounds.south);
    final ppd = math.min(
      math.min((_view.width - 32) / w, (_view.height - 32) / h),
      _ppdForFlat(widget.focusMaxZoom),
    );
    return (lon: lng, lat: lat, zoom: _clampZoom(ppd / (_baseRadius * _deg)));
  }

  void _moveTo(
    double lat,
    double lng, {
    double? flatZoom,
    bool animate = false,
  }) {
    _stopMotion();
    final zoom = flatZoom == null ? null : _clampZoom(_zoomForFlat(flatZoom));
    if (animate) {
      _panTarget = (lon: lng, lat: lat);
      _zoomTarget = zoom;
      _ensureTicking();
      _cam.changed(); // listeners learn at once that a flight has begun
      return;
    }
    _cam
      ..lon = lng
      ..lat = lat;
    if (zoom != null) _cam.zoom = zoom;
    _normalize();
    _cam.changed();
  }

  /// Start over the user's own travels; Uzbekistan when there are none.
  ({double lon, double lat}) _homeCenter() {
    final geo = GeoRegions.instance;
    var sx = 0.0;
    var sy = 0.0;
    var sz = 0.0;
    void add(double lng, double lat) {
      final cl = math.cos(lat * _deg);
      sx += cl * math.cos(lng * _deg);
      sy += cl * math.sin(lng * _deg);
      sz += math.sin(lat * _deg);
    }

    for (final iso in widget.visitedCounts.keys) {
      final r = geo.regionByIso(iso);
      if (r != null) add(r.centroidLngLat.dx, r.centroidLngLat.dy);
    }
    for (final p in widget.points) {
      add(p.lng, p.lat);
    }
    final len = math.sqrt(sx * sx + sy * sy + sz * sz);
    if (len < 1e-6) return (lon: 64.5, lat: 41.3);
    return (lon: math.atan2(sy, sx) / _deg, lat: math.asin(sz / len) / _deg);
  }

  // --- animation ---------------------------------------------------------------

  void _ensureTicking() {
    final ticker = _ticker ??= createTicker(_tick);
    if (!ticker.isActive) {
      _lastTick = Duration.zero;
      ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;
    final ppd = _ppd;
    var changed = false;

    final target = _panTarget;
    if (target != null) {
      final k = math.min(1.0, dt * 6);
      var dLon = target.lon - _cam.lon;
      if (dLon > 180) dLon -= 360;
      if (dLon < -180) dLon += 360;
      final dLat = target.lat - _cam.lat;
      _cam
        ..lon += dLon * k
        ..lat += dLat * k;
      // Within a pixel or so, land exactly on the target and end the flight.
      if ((dLon.abs() + dLat.abs()) * ppd < 1.5) {
        _cam
          ..lon = target.lon
          ..lat = target.lat;
        _panTarget = null;
      }
      changed = true;
    } else if ((_vLon.abs() + _vLat.abs()) * ppd > 15) {
      _cam
        ..lon += _vLon * dt
        ..lat += _vLat * dt;
      final f = math.pow(0.08, dt).toDouble(); // exponential friction
      _vLon *= f;
      _vLat *= f;
      changed = true;
    } else if (_autoRotate) {
      _cam.lon += 5 * dt; // gentle spin until the first touch
      changed = true;
    }

    final zt = _zoomTarget;
    if (zt != null) {
      // Ease in log space so every zoom step feels the same speed.
      _cam.zoom *= math.pow(zt / _cam.zoom, math.min(1.0, dt * 9)).toDouble();
      if ((zt / _cam.zoom - 1).abs() < 0.002) {
        _cam.zoom = zt;
        _zoomTarget = null;
      }
      changed = true;
    }

    if (changed) {
      _normalize();
      _cam.changed();
    } else {
      _ticker?.stop();
    }
  }

  void _normalize() {
    _cam
      ..lat = _cam.lat.clamp(-85.0, 85.0)
      ..lon = ((_cam.lon + 180) % 360 + 360) % 360 - 180;
  }

  // --- geometry ------------------------------------------------------------------

  /// The globe's radius at zoom 1: the whole globe, with a margin.
  /// The visible part of the globe's area ([GlobeView.padding] removed).
  Rect get _view => _visibleRect(_size, widget.padding);

  double get _baseRadius =>
      math.min(_view.width, _view.height) / 2 * _globeFill;

  double get _radius => _baseRadius * _cam.zoom;

  /// Pixels per degree of arc at the centre of the globe.
  double get _ppd => _radius * _deg;

  /// The globe zoom whose scale matches flat-map zoom level [flat].
  double _zoomForFlat(double flat) =>
      _baseRadius > 0 ? _ppdForFlat(flat) / (_baseRadius * _deg) : 1;

  /// The current scale as a flat-map zoom level.
  double get _flatZoom {
    final ppd = _ppd;
    return ppd > 0 ? math.log(ppd * 360 / 256) / math.ln2 : 3;
  }

  /// Out to the whole globe; in to the flat maps' ceiling.
  double _clampZoom(double zoom) {
    final max = _baseRadius > 0 ? _zoomForFlat(_maxFlatZoom) : 2000.0;
    return zoom.clamp(_minZoom, math.max(_minZoom, max));
  }

  /// Drags turn the globe about its axis. Zoomed in, a degree of longitude is
  /// only cos(lat) wide, so scale up to keep the spot under the finger; zoomed
  /// out, the plain spin feels more natural.
  double get _lonScale {
    final t = ((_cam.zoom - 1) / 2).clamp(0.0, 1.0);
    final s = 1 / math.max(0.1, math.cos(_cam.lat * _deg));
    return 1 + (s - 1) * t;
  }

  /// Screen point -> lon/lat (inverse orthographic), or null off the globe.
  ({double lng, double lat})? _unproject(Offset local) {
    final r = _radius;
    final c = _view.center;
    final x = (local.dx - c.dx) / r;
    final y = -(local.dy - c.dy) / r;
    final rho = math.sqrt(x * x + y * y);
    if (rho > 1) return null;
    final p0 = _cam.lat * _deg;
    if (rho < 1e-12) return (lng: _cam.lon, lat: _cam.lat);
    final cc = math.asin(rho);
    final sinC = math.sin(cc);
    final cosC = math.cos(cc);
    final lat = math.asin(cosC * math.sin(p0) + y * sinC * math.cos(p0) / rho);
    final lng =
        _cam.lon * _deg +
        math.atan2(
          x * sinC,
          rho * cosC * math.cos(p0) - y * sinC * math.sin(p0),
        );
    return (lng: lng / _deg, lat: lat / _deg);
  }

  Offset? _project(double lng, double lat) {
    final p0 = _cam.lat * _deg;
    final la = lat * _deg;
    final dl = lng * _deg - _cam.lon * _deg;
    final z =
        math.sin(p0) * math.sin(la) +
        math.cos(p0) * math.cos(la) * math.cos(dl);
    if (z < 0) return null;
    final r = _radius;
    final c = _view.center;
    final x = math.cos(la) * math.sin(dl);
    final y =
        math.cos(p0) * math.sin(la) -
        math.sin(p0) * math.cos(la) * math.cos(dl);
    return Offset(c.dx + r * x, c.dy - r * y);
  }

  // --- gestures ------------------------------------------------------------------
  //
  // Raw pointers rather than a GestureDetector: the profile page scrolls
  // vertically, and a scale recogniser only wins the gesture arena after a
  // 36 px slop — the page's vertical drag (18 px) won first, so dragging the
  // globe scrolled the whole profile instead. An EagerGestureRecognizer claims
  // every pointer that lands on the globe, and these handlers do the rest.

  void _stopMotion() {
    final wasFlying = _panTarget != null;
    _autoRotate = false;
    _vLon = 0;
    _vLat = 0;
    _panTarget = null;
    _zoomTarget = null;
    // A touch can cut a flight short without moving anything; still tell
    // listeners it is over (see [GlobeController.flying]).
    if (wasFlying) _cam.changed();
  }

  Offset get _focal {
    var sum = Offset.zero;
    for (final p in _pointers.values) {
      sum += p;
    }
    return sum / _pointers.length.toDouble();
  }

  void _startPinch() {
    final pts = _pointers.values.toList();
    _pinchDistance = (pts[0] - pts[1]).distance;
    _pinchZoom = _cam.zoom;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    _stopMotion();
    if (_ticker?.isActive ?? false) _ticker!.stop();
    if (_pointers.length == 1) {
      _velocity = VelocityTracker.withKind(e.kind)
        ..addPosition(e.timeStamp, e.localPosition);
      _downAt = e.localPosition;
      _downTime = e.timeStamp;
      _tapCandidate = true;
    } else {
      _tapCandidate = false;
      _velocity = null;
      _startPinch();
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    final before = _focal;
    final r0 = _radius;
    _pointers[e.pointer] = e.localPosition;
    final after = _focal;

    if (_pointers.length >= 2) {
      if (_pinchDistance > 0) {
        final pts = _pointers.values.toList();
        final distance = (pts[0] - pts[1]).distance;
        _cam.zoom = _clampZoom(_pinchZoom * distance / _pinchDistance);
        // Zoom about the fingers: keep the spot under them where it is.
        final r1 = _radius;
        final f = after - _view.center;
        _cam
          ..lon += (f.dx / r0 - f.dx / r1) / _deg * _lonScale
          ..lat -= (f.dy / r0 - f.dy / r1) / _deg;
      }
    } else {
      _velocity?.addPosition(e.timeStamp, e.localPosition);
      final down = _downAt;
      if (down != null && (e.localPosition - down).distance > kTouchSlop) {
        _tapCandidate = false;
      }
    }

    // Drag rotates: moving the surface right turns the view west, down turns
    // it north. Scaled by the radius so the finger stays on the same spot.
    final d = after - before;
    final r = _radius;
    _cam
      ..lon -= d.dx / r / _deg * _lonScale
      ..lat += d.dy / r / _deg;
    _normalize();
    _cam.changed();
  }

  void _onPointerEnd(PointerEvent e) {
    if (_pointers.remove(e.pointer) == null) return;
    if (_pointers.length >= 2) {
      _startPinch();
      return;
    }
    if (_pointers.length == 1) {
      // Pinch over: the remaining finger keeps rotating, but never flings.
      _velocity = null;
      _downAt = null;
      return;
    }
    if (e is PointerUpEvent &&
        _tapCandidate &&
        e.timeStamp - _downTime < const Duration(milliseconds: 350)) {
      _onTap(e.localPosition, e.timeStamp);
    } else {
      final v = _velocity?.getVelocity().pixelsPerSecond;
      if (v != null && v.distance > 80) {
        final r = _radius;
        _vLon = -v.dx / r / _deg * _lonScale;
        _vLat = v.dy / r / _deg;
      }
    }
    _velocity = null;
    _ensureTicking();
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final scroll = event as PointerScrollEvent;
      _stopMotion();
      _zoomTarget = _clampZoom(
        _cam.zoom * math.pow(2, -scroll.scrollDelta.dy / 200),
      );
      _ensureTicking();
    });
  }

  /// A single tap opens what is under it; it waits out the double-tap window
  /// first, since a double tap zooms instead.
  void _onTap(Offset at, Duration time) {
    final last = _lastTapAt;
    if (last != null &&
        time - _lastTapTime < kDoubleTapTimeout &&
        (at - last).distance < kDoubleTapSlop) {
      _tapTimer?.cancel();
      _lastTapAt = null;
      _zoomInAt(at);
      return;
    }
    _lastTapAt = at;
    _lastTapTime = time;
    _tapTimer?.cancel();
    _tapTimer = Timer(kDoubleTapTimeout, () {
      _lastTapAt = null;
      if (mounted) _openAt(at);
    });
  }

  void _zoomInAt(Offset at) {
    final ll = _unproject(at);
    _stopMotion();
    if (ll != null) _panTarget = (lon: ll.lng, lat: ll.lat);
    _zoomTarget = _clampZoom(_cam.zoom * 2.2);
    _ensureTicking();
  }

  void _zoomBy(double factor) {
    // Quick repeated taps add up rather than restarting from mid-animation.
    final from = _zoomTarget ?? _cam.zoom;
    _stopMotion();
    _zoomTarget = _clampZoom(from * factor);
    _ensureTicking();
  }

  /// "My location": back to the opening view. The profile globe opens whole,
  /// over the user's travels, which may have loaded since — so it re-centres.
  void _reset() {
    _stopMotion();
    final v = _initialView;
    if (v != null &&
        (widget.focusBounds != null || widget.initialCenter != null)) {
      _panTarget = (lon: v.lon, lat: v.lat);
      _zoomTarget = v.zoom;
    } else {
      _panTarget = _homeCenter();
      _zoomTarget = 1;
    }
    _ensureTicking();
  }

  /// How near a tap must land (in logical pixels) to count as hitting a pin,
  /// measured to the pin's point — each flat map's own radius.
  double get _pinHitRadius => widget.look == GlobeLook.picker ? 28 : 24;

  /// The pin nearest [at] within [_pinHitRadius], or null.
  _GlobePin? _pinAt(Offset at) {
    final scene = _scene;
    if (scene == null) return null;
    _GlobePin? best;
    var bestDistance = double.infinity;
    for (final pin in scene.pins) {
      final s = _project(pin.point.lng, pin.point.lat);
      if (s == null) continue;
      final d = (s - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = pin;
      }
    }
    return bestDistance <= _pinHitRadius ? best : null;
  }

  /// Whether each region's pins are merged into one (zoomed out).
  bool get _pinsMerged => !_atZoom(_cam.zoom, _pinsSplitZoom);

  /// A merged pin of several places flies in to where they show one by one;
  /// returns the single place of a one-pin region instead (or null on a miss).
  _GlobePin? _mergedPinAt(Offset at) {
    final group = _groupAt(at);
    if (group == null || group.pins.length == 1) return group?.pins.first;
    _stopMotion();
    final c = group.latLng;
    _panTarget = (lon: c.lng, lat: c.lat);
    _zoomTarget = _clampZoom(math.max(_cam.zoom, _pinsSplitZoom));
    _ensureTicking();
    _cam.changed(); // listeners learn at once that a flight has begun
    return null;
  }

  /// The merged pin nearest [at] within [_pinHitRadius], or null.
  _PinGroup? _groupAt(Offset at) {
    final scene = _scene;
    if (scene == null) return null;
    _PinGroup? best;
    var bestDistance = double.infinity;
    for (final group in scene.groups) {
      final c = group.latLng;
      final s = _project(c.lng, c.lat);
      if (s == null) continue;
      final d = (s - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = group;
      }
    }
    return bestDistance <= _pinHitRadius ? best : null;
  }

  void _openAt(Offset at) {
    if (widget.look == GlobeLook.picker) {
      // The picker: tapping one of your existing places re-picks it.
      final hit = _pinsMerged ? _mergedPinAt(at) : _pinAt(at);
      if (hit != null) widget.onPinTap?.call(hit.point);
      return;
    }

    // [TravelMap]'s rule: a pin wins; otherwise only onboarding
    // ([GlobeView.tapAnyRegion]) reports the region under the tap. On the
    // profile a bare tap on a province — even a visited one — does nothing;
    // its whole-region feed is reached from inside a pin's page.
    final onTap = widget.onTargetTap;
    final geo = GeoRegions.instance;
    final scene = _scene;
    if (onTap == null || !geo.isLoaded || scene == null) return;
    final hit = _pinsMerged ? _mergedPinAt(at) : _pinAt(at);
    final probe = hit == null
        ? _unproject(at)
        : (lng: hit.point.lng, lat: hit.point.lat);
    if (probe == null) return;
    final region = geo.regionAt(probe.lng, probe.lat);
    // Ocean: nothing under the tap.
    if (region == null) return;
    if (!widget.tapAnyRegion && hit == null) return;

    onTap(TravelMapTarget(region: region, point: hit?.point));
    if (hit == null) return;

    // Opening a pin shows all of its content, so catch its seen count up to
    // whatever it holds now. New posts/stories later push the count higher
    // and the pin goes white again.
    final current = scene.pinCounts[hit.key] ?? 1;
    if (_seenCounts[hit.key] != current) {
      _seenCounts[hit.key] = current;
      _legacySeen.remove(hit.key);
      if (mounted) setState(() {});
      unawaited(_persistSeenCounts());
    }
  }

  // --- pin seen-state -------------------------------------------------------------
  //
  // The flat map's store and rules (TravelMap._seenCounts and friends), on the
  // same SharedPreferences keys — so a pin opened on either map is dimmed on
  // both. A pin stays white while it holds more posts + stories than when it
  // was last opened, and dims once opened.

  static const _seenStoreKey = 'treepnet_seen_map_pins'; // legacy List<String>
  static const _seenCountsKey = 'treepnet_seen_map_counts'; // JSON {key: count}

  final _seenCounts = <String, int>{};

  /// Legacy boolean "seen" keys written before counts were tracked. On first
  /// sight they are snapshotted to their current count (see [_seedLegacySeen]).
  final _legacySeen = <String>{};

  /// The scene [_seedLegacySeen] last ran against.
  _GlobeScene? _seededScene;

  Future<void> _loadSeenPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getStringList(_seenStoreKey);
    final raw = prefs.getString(_seenCountsKey);
    if (!mounted) return;
    setState(() {
      if (legacy != null) _legacySeen.addAll(legacy);
      if (raw != null && raw.isNotEmpty) {
        (json.decode(raw) as Map<String, dynamic>).forEach(
          (k, v) => _seenCounts[k] = (v as num).toInt(),
        );
      }
      _seededScene = null; // re-seed against the state that just arrived
    });
  }

  Future<void> _persistSeenCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seenCountsKey, json.encode(_seenCounts));
  }

  bool _isPinSeen(_GlobeScene scene, String key) {
    final seen = _seenCounts[key];
    if (seen == null) return _legacySeen.contains(key);
    return seen >= (scene.pinCounts[key] ?? 0);
  }

  /// Snapshots legacy-seen pins to their current count so they stay dimmed
  /// until genuinely new content arrives, then drops them from the legacy set.
  void _seedLegacySeen(_GlobeScene scene) {
    if (_legacySeen.isEmpty) return;
    var changed = false;
    for (final k in scene.pinCounts.keys.toList()) {
      if (_legacySeen.remove(k) && !_seenCounts.containsKey(k)) {
        _seenCounts[k] = scene.pinCounts[k]!;
        changed = true;
      }
    }
    if (changed) unawaited(_persistSeenCounts());
  }

  // --- build ---------------------------------------------------------------------

  _GlobeScene _sceneFor(String lang, String? fontFamily) {
    final geoLoaded = GeoRegions.instance.isLoaded;
    final s = _scene;
    if (s != null &&
        s.look == widget.look &&
        s.lang == lang &&
        s.fontFamily == fontFamily &&
        s.geoLoaded == geoLoaded &&
        identical(s.counts, widget.visitedCounts) &&
        identical(s.points, widget.points)) {
      return s;
    }
    return _scene = _GlobeScene.build(
      counts: widget.visitedCounts,
      points: widget.points,
      look: widget.look,
      lang: lang,
      fontFamily: fontFamily,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = _sceneFor(
      Localizations.localeOf(context).languageCode,
      DefaultTextStyle.of(context).style.fontFamily,
    );
    // Only [TravelMap] dims opened pins; the picker's pins never change colour.
    var seen = const <String>{};
    if (widget.look == GlobeLook.travelMap) {
      if (!identical(_seededScene, scene)) {
        _seededScene = scene;
        _seedLegacySeen(scene);
      }
      seen = {
        for (final pin in scene.pins)
          if (_isPinSeen(scene, pin.key)) pin.key,
      };
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ColoredBox(
        color: const Color(0xFF15181B),
        child: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                _size = constraints.biggest;
                _applyInitialView();
                return RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    EagerGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          EagerGestureRecognizer
                        >(EagerGestureRecognizer.new, (_) {}),
                  },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerEnd,
                    onPointerCancel: _onPointerEnd,
                    onPointerSignal: _onPointerSignal,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _GlobePainter(
                          camera: _cam,
                          scene: scene,
                          seen: seen,
                          padding: widget.padding,
                          split: _split,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.showButtons)
              Positioned(
                right: 8,
                bottom: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlobeButton(icon: Icons.add, onTap: () => _zoomBy(2)),
                    const SizedBox(height: 8),
                    _GlobeButton(
                      icon: Icons.remove,
                      onTap: () => _zoomBy(0.5),
                    ),
                    const SizedBox(height: 8),
                    _GlobeButton(icon: Icons.my_location, onTap: _reset),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlobeButton extends StatelessWidget {
  const _GlobeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: AppColors.white),
        ),
      ),
    );
  }
}

// --- data -------------------------------------------------------------------------

/// A point on the unit sphere.
class _Anchor {
  _Anchor(double lng, double lat)
    : x = math.cos(lat * _deg) * math.cos(lng * _deg),
      y = math.cos(lat * _deg) * math.sin(lng * _deg),
      z = math.sin(lat * _deg);

  _Anchor._unit(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

/// One region's pins, drawn as a single pin while the travel-map globe is
/// zoomed out (see [_pinsSplitZoom]).
class _PinGroup {
  _PinGroup._(this.pins, this.at);

  /// Sits at the middle of its pins (their mean direction on the sphere).
  factory _PinGroup.of(List<_GlobePin> pins) {
    var sx = 0.0;
    var sy = 0.0;
    var sz = 0.0;
    for (final pin in pins) {
      sx += pin.at.x;
      sy += pin.at.y;
      sz += pin.at.z;
    }
    final len = math.sqrt(sx * sx + sy * sy + sz * sz);
    return _PinGroup._(
      pins,
      len < 1e-9 ? pins.first.at : _Anchor._unit(sx / len, sy / len, sz / len),
    );
  }

  final List<_GlobePin> pins;
  final _Anchor at;

  ({double lat, double lng}) get latLng => (
    lat: math.asin(at.z.clamp(-1.0, 1.0)) / _deg,
    lng: math.atan2(at.y, at.x) / _deg,
  );
}

/// The flat map's pin key (`TravelMap._pointKey`) — also the seen-state key,
/// so both maps read and write the same entries.
String _pinKey(double lat, double lng) => '$lat,$lng';

class _GlobePin {
  _GlobePin(this.point, this.label)
    : key = _pinKey(point.lat, point.lng),
      at = _Anchor(point.lng, point.lat);

  /// The first post/story at this spot — what a tap opens, as on the flat map.
  final ({double lat, double lng, String? name}) point;
  final String key;
  final _Anchor at;

  /// The place name printed under the pin once zoomed in.
  String label;
}

class _CountryName {
  _CountryName(this.label) : at = _Anchor(label.center.dx, label.center.dy);

  final CountryLabel label;
  final _Anchor at;
}

class _RegionName {
  _RegionName(this.region, Rect bounds)
    : at = _Anchor(region.centroidLngLat.dx, region.centroidLngLat.dy),
      widthDeg = bounds.width * math.cos(region.centroidLngLat.dy * _deg),
      heightDeg = bounds.height;

  final GeoRegion region;
  final _Anchor at;

  /// On-sphere size of the region's bounding box, in degrees of arc.
  final double widthDeg;
  final double heightDeg;
}

/// Everything the painter needs that changes only with the data or language.
class _GlobeScene {
  _GlobeScene._({
    required this.counts,
    required this.points,
    required this.look,
    required this.lang,
    required this.fontFamily,
    required this.geoLoaded,
    required this.visited,
    required this.pins,
    required this.groups,
    required this.pinCounts,
    required this.pinNames,
  });

  factory _GlobeScene.build({
    required Map<String, int> counts,
    required List<({double lat, double lng, String? name})> points,
    required GlobeLook look,
    required String lang,
    required String? fontFamily,
  }) {
    final geo = GeoRegions.instance;
    final visited = <Color, List<_Layer>>{};
    final pins = <String, _GlobePin>{};
    final pinCounts = <String, int>{};
    final pinNames = <String>{};
    if (geo.isLoaded) {
      for (final e in counts.entries) {
        final region = geo.regionByIso(e.key);
        if (region == null) continue;
        visited
            .putIfAbsent(travelMapColorForCount(e.value), () => [])
            .add(_GlobeData.region(region));
      }
    }
    for (final p in points) {
      // The flat map draws one identical pin per post; posts from one spot
      // share a single pin here. As there, a tap opens the first point at the
      // spot, the label shown is the last one's, and the count (posts +
      // stories) drives the seen state. The picker prints the stored name
      // as-is; [TravelMap] localizes a name that is just the region's.
      final String label;
      if (look == GlobeLook.picker) {
        label = (p.name?.trim().isNotEmpty ?? false) ? p.name! : '';
      } else {
        label = geo.isLoaded ? _pinLabel(p, lang) : (p.name ?? '');
      }
      final key = _pinKey(p.lat, p.lng);
      pins.putIfAbsent(key, () => _GlobePin(p, label)).label = label;
      pinCounts[key] = (pinCounts[key] ?? 0) + 1;
      final name = p.name?.trim() ?? '';
      if (name.isNotEmpty) pinNames.add(name.toLowerCase());
    }
    // A region's pins merge while zoomed out. A pin outside every region
    // (out at sea) stays on its own.
    final byRegion = <String, List<_GlobePin>>{};
    for (final pin in pins.values) {
      final iso = geo.isLoaded
          ? geo.regionAt(pin.point.lng, pin.point.lat)?.iso
          : null;
      byRegion.putIfAbsent(iso ?? pin.key, () => []).add(pin);
    }
    return _GlobeScene._(
      counts: counts,
      points: points,
      look: look,
      lang: lang,
      fontFamily: fontFamily,
      geoLoaded: geo.isLoaded,
      visited: visited,
      pins: pins.values.toList(),
      groups: [for (final group in byRegion.values) _PinGroup.of(group)],
      pinCounts: pinCounts,
      pinNames: pinNames,
    );
  }

  /// Same rule as the flat map: the author's own name for the spot, else the
  /// region it falls in, in the app language.
  static String _pinLabel(
    ({double lat, double lng, String? name}) p,
    String lang,
  ) {
    final typed = p.name?.trim() ?? '';
    final region = GeoRegions.instance.regionAt(p.lng, p.lat);
    if (region != null && (typed.isEmpty || typed == region.name.trim())) {
      return region.localizedDisplayName(lang);
    }
    return typed;
  }

  final Map<String, int> counts;
  final List<({double lat, double lng, String? name})> points;
  final GlobeLook look;
  final String lang;
  final String? fontFamily;
  final bool geoLoaded;

  /// Visited regions grouped by their travel-map colour.
  final Map<Color, List<_Layer>> visited;
  final List<_GlobePin> pins;

  /// The pins by region, for the zoomed-out view.
  final List<_PinGroup> groups;

  /// How many points (posts + stories) sit at each pin key.
  final Map<String, int> pinCounts;

  /// Lower-cased names the author gave their pins.
  final Set<String> pinNames;

  // A crisp 1px outline (four hard offset copies, no blur) — as on the flat map.
  static const _outline = <Shadow>[
    Shadow(color: AppColors.black, offset: Offset(0, 1)),
    Shadow(color: AppColors.black, offset: Offset(0, -1)),
    Shadow(color: AppColors.black, offset: Offset(1, 0)),
    Shadow(color: AppColors.black, offset: Offset(-1, 0)),
  ];

  late final countryStyle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.white,
    fontSize: 13,
    height: 1,
    fontWeight: FontWeight.w600,
    shadows: _outline,
  );

  late final provinceStyle = countryStyle.copyWith(
    color: const Color(0xFFDCE6FF),
  );

  late final pinNameStyle = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.white,
    fontSize: 11,
    height: 1,
    // Heaviest label on the map: a place the user named outranks the
    // country/province names underneath it.
    fontWeight: FontWeight.w900,
    shadows: _outline,
  );

  static final pinGlyph = String.fromCharCode(Icons.location_on.codePoint);

  /// White while a pin holds content you haven't opened yet.
  static final pinStyle = TextStyle(
    fontFamily: Icons.location_on.fontFamily,
    package: Icons.location_on.fontPackage,
    color: AppColors.white,
    fontSize: 26,
    height: 1,
    shadows: _outline,
  );

  /// Dimmed once you have opened everything behind it (the flat map's
  /// `_seenPinColor`).
  static final seenPinStyle = pinStyle.copyWith(color: const Color(0xFF414141));

  /// The location picker's smaller pin.
  static final pickerPinStyle = pinStyle.copyWith(fontSize: 22);
}

/// A set of lng/lat rings, put on the sphere lazily at each level of detail on
/// first use.
class _Layer {
  _Layer(this._rings);

  final List<List<Offset>> _rings;
  final _levels = <double, List<_SphereRing>>{};

  List<_SphereRing> at(double step) => _levels.putIfAbsent(step, () {
    final out = <_SphereRing>[];
    for (final ring in _rings) {
      final s = _SphereRing.fromLngLat(ring, step);
      if (s != null) out.add(s);
    }
    return out;
  });
}

/// The base geometry on the sphere, built once per session and shared.
class _GlobeData {
  _GlobeData._(this._geo) : countries = _Layer(_geo.countryRings);

  final GeoRegions _geo;
  final _Layer countries;

  /// Every admin-1 ring. Lazy: parsing all ~4,500 regions is the slow part.
  late final provinces = _Layer([
    for (final region in _geo.allRegions) ...region.rings,
  ]);

  late final countryLabels = [
    for (final label in _geo.countryLabels) _CountryName(label),
  ];

  late final regionLabels = _regionLabels();

  List<_RegionName> _regionLabels() {
    final out = <_RegionName>[];
    for (final region in _geo.allRegions) {
      final bounds = region.lngLatBounds;
      if (bounds != Rect.zero) out.add(_RegionName(region, bounds));
    }
    return out;
  }

  static _GlobeData? _instance;
  static final _regions = <String, _Layer>{};

  static _GlobeData of(GeoRegions geo) => _instance ??= _GlobeData._(geo);

  static _Layer region(GeoRegion region) =>
      _regions.putIfAbsent(region.iso, () => _Layer(region.rings));
}

/// One ring as unit vectors (x, y, z per point) plus the smallest spherical
/// cap around (cx, cy, cz) that holds it — used to cull whole rings.
class _SphereRing {
  _SphereRing(this.xyz, this.cx, this.cy, this.cz, this.cap);

  final Float32List xyz;
  final double cx;
  final double cy;
  final double cz;

  /// Angular radius of the smallest cap around (cx, cy, cz) holding the ring.
  final double cap;

  static _SphereRing? fromLngLat(List<Offset> ring, double minStepDeg) {
    if (ring.length < 3) return null;
    final out = <double>[];
    double? lastLng;
    double? lastLat;
    for (var i = 0; i < ring.length; i++) {
      final p = ring[i];
      if (lastLng != null && i != ring.length - 1) {
        final dLng = (p.dx - lastLng).abs() * math.cos(p.dy * _deg);
        if (dLng + (p.dy - lastLat!).abs() < minStepDeg) continue;
      }
      lastLng = p.dx;
      lastLat = p.dy;
      final la = p.dy * _deg;
      final lo = p.dx * _deg;
      final cl = math.cos(la);
      out
        ..add(cl * math.cos(lo))
        ..add(cl * math.sin(lo))
        ..add(math.sin(la));
    }
    if (out.length < 9) return null;
    var sx = 0.0;
    var sy = 0.0;
    var sz = 0.0;
    for (var i = 0; i < out.length; i += 3) {
      sx += out[i];
      sy += out[i + 1];
      sz += out[i + 2];
    }
    final len = math.sqrt(sx * sx + sy * sy + sz * sz);
    double cx;
    double cy;
    double cz;
    if (len < 1e-9) {
      cx = 1;
      cy = 0;
      cz = 0;
    } else {
      cx = sx / len;
      cy = sy / len;
      cz = sz / len;
    }
    var minDot = 1.0;
    for (var i = 0; i < out.length; i += 3) {
      final d = out[i] * cx + out[i + 1] * cy + out[i + 2] * cz;
      if (d < minDot) minDot = d;
    }
    final cap = len < 1e-9 ? math.pi : math.acos(minDot.clamp(-1.0, 1.0));
    return _SphereRing(Float32List.fromList(out), cx, cy, cz, cap);
  }
}

// --- painter ----------------------------------------------------------------------

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.camera,
    required this.scene,
    required this.seen,
    required this.padding,
    this.split,
  }) : super(
         repaint: split == null ? camera : Listenable.merge([camera, split]),
       );

  final _Camera camera;
  final _GlobeScene scene;

  /// Keys of the pins whose content has all been opened (drawn dimmed).
  final Set<String> seen;

  /// See [GlobeView.padding].
  final EdgeInsets padding;

  /// See [_GlobeViewState._split].
  final Animation<double>? split;

  static Float64List _buf = Float64List(4096);

  // Laid-out labels, reused across frames.
  static final _texts = <String, TextPainter>{};

  static TextPainter _text(
    String text,
    TextStyle style, {
    double maxWidth = double.infinity,
  }) {
    final key = '${style.hashCode}|$maxWidth|$text';
    return _texts[key] ??= TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: maxWidth.isFinite ? '…' : null,
    )..layout(maxWidth: maxWidth);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Trim the label cache between frames, never mid-paint: a disposed
    // painter must not be drawn.
    if (_texts.length > 4000) {
      for (final t in _texts.values) {
        t.dispose();
      }
      _texts.clear();
    }
    final view = _visibleRect(size, padding);
    final c = view.center;
    final r =
        math.min(view.width, view.height) / 2 * _globeFill * camera.zoom;
    final ppd = r * _deg;
    final l0 = camera.lon * _deg;
    final p0 = camera.lat * _deg;
    final cosL0 = math.cos(l0);
    final sinL0 = math.sin(l0);
    final cosP0 = math.cos(p0);
    final sinP0 = math.sin(p0);
    final vx = cosP0 * cosL0;
    final vy = cosP0 * sinL0;
    final vz = sinP0;

    // Half-angle of the sphere that can reach the viewport (smaller zoomed in),
    // from the panel corner farthest from the globe's centre.
    var halfDiag = 0.0;
    for (final corner in [
      Offset.zero,
      size.topRight(Offset.zero),
      size.bottomLeft(Offset.zero),
      size.bottomRight(Offset.zero),
    ]) {
      halfDiag = math.max(halfDiag, (corner - c).distance);
    }
    final visAngle = r > halfDiag ? math.asin(halfDiag / r) : math.pi / 2;
    // Zoomed in far enough, the disc covers the whole panel: no edge to draw,
    // no glow and no clip (a blur or clip that size would be very costly).
    final edgeVisible = r < halfDiag;

    final globe = Rect.fromCircle(center: c, radius: r);
    final ocean = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [
          Color(0xFF3E464E),
          MapBaseLayers.oceanColor,
          Color(0xFF181B1E),
        ],
        stops: [0, 0.55, 1],
      ).createShader(globe);

    if (edgeVisible) {
      // Atmosphere glow, then the ocean with a soft light from the upper left.
      canvas
        ..drawCircle(
          c,
          r * 1.015,
          Paint()
            ..color = const Color(0x6658A6FF)
            ..maskFilter = MaskFilter.blur(BlurStyle.outer, r * 0.06),
        )
        ..drawCircle(c, r, ocean)
        ..save()
        ..clipPath(Path()..addOval(globe));
    } else {
      canvas.drawRect(Offset.zero & size, ocean);
    }

    /// Whether [ring] can't touch the screen: wholly on the far side, or
    /// outside the cap the viewport can see.
    bool culled(_SphereRing ring) {
      final d = ring.cx * vx + ring.cy * vy + ring.cz * vz;
      if (ring.cap < math.pi / 2 && d < -math.sin(ring.cap)) return true;
      if (visAngle + ring.cap < math.pi && d < math.cos(visAngle + ring.cap)) {
        return true;
      }
      return false;
    }

    /// Adds [ring] to an [area] to fill and/or an [outline] to stroke.
    ///
    /// The fill must stay closed, so the part behind the horizon is walked
    /// around the rim: each far-side point goes to the rim in its own
    /// direction, with rim points in between when two of them are far apart.
    /// (Joining them straight cut chords across the visible side — long
    /// lines and wedges over the ocean.) The outline just lifts the pen
    /// behind the horizon, so no border is drawn along the rim.
    void addRing(_SphereRing ring, {Path? area, Path? outline}) {
      if (culled(ring)) return;
      final xyz = ring.xyz;
      var n = 0;
      var anyVisible = false;
      var pen = false;
      var behind = false;
      var lastAngle = 0.0;
      void put(double x, double y) {
        if (_buf.length < n + 2) {
          _buf = Float64List(_buf.length * 2)..setRange(0, n, _buf);
        }
        _buf[n++] = x;
        _buf[n++] = y;
      }

      for (var i = 0; i < xyz.length; i += 3) {
        final x0 = xyz[i];
        final y0 = xyz[i + 1];
        final z0 = xyz[i + 2];
        final a = x0 * cosL0 + y0 * sinL0;
        final x = y0 * cosL0 - x0 * sinL0;
        final y = cosP0 * z0 - sinP0 * a;
        final z = sinP0 * z0 + cosP0 * a;
        if (z >= 0) {
          anyVisible = true;
          behind = false;
          final sx = c.dx + r * x;
          final sy = c.dy - r * y;
          if (area != null) put(sx, sy);
          if (outline != null) {
            if (pen) {
              outline.lineTo(sx, sy);
            } else {
              outline.moveTo(sx, sy);
              pen = true;
            }
          }
          continue;
        }
        pen = false;
        if (area == null) continue;
        final angle = math.atan2(y, x);
        if (behind) {
          // The shorter way round — right for any path that doesn't cross
          // the exact point opposite the view.
          var d = angle - lastAngle;
          if (d > math.pi) d -= 2 * math.pi;
          if (d < -math.pi) d += 2 * math.pi;
          final steps = (d.abs() / 0.1).floor();
          for (var k = 1; k <= steps; k++) {
            final t = lastAngle + d * k / (steps + 1);
            put(c.dx + r * math.cos(t), c.dy - r * math.sin(t));
          }
        }
        put(c.dx + r * math.cos(angle), c.dy - r * math.sin(angle));
        behind = true;
        lastAngle = angle;
      }
      // A ring wholly behind would only trace the rim (and could wrap the
      // whole globe), so it adds nothing.
      if (area == null || !anyVisible || n < 6) return;
      area.moveTo(_buf[0], _buf[1]);
      for (var j = 2; j < n; j += 2) {
        area.lineTo(_buf[j], _buf[j + 1]);
      }
      area.close();
    }

    // Screen position of an anchor, written to (px, py); returns its depth
    // (above 0 on the near side).
    var px = 0.0;
    var py = 0.0;
    double project(_Anchor p) {
      final a = p.x * cosL0 + p.y * sinL0;
      px = c.dx + r * (p.y * cosL0 - p.x * sinL0);
      py = c.dy - r * (cosP0 * p.z - sinP0 * a);
      return sinP0 * p.z + cosP0 * a;
    }

    bool onScreen(double margin) =>
        px > -margin &&
        py > -margin &&
        px < size.width + margin &&
        py < size.height + margin;

    // Graticule every 30° — faint, under the land; it's what reads as a globe
    // over the open ocean. Only at globe scale.
    if (ppd < 40) {
      final grid = Path();
      for (var lo = -180; lo < 180; lo += 30) {
        _addLine(grid, [
          for (var la = -90; la <= 90; la += 3)
            Offset(lo.toDouble(), la.toDouble()),
        ], c, r, cosL0, sinL0, cosP0, sinP0);
      }
      for (var la = -60; la <= 60; la += 30) {
        _addLine(grid, [
          for (var lo = -180; lo <= 180; lo += 3)
            Offset(lo.toDouble(), la.toDouble()),
        ], c, r, cosL0, sinL0, cosP0, sinP0);
      }
      canvas.drawPath(
        grid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0x14FFFFFF),
      );
    }

    final step = _stepFor(ppd);
    final data = scene.geoLoaded ? _GlobeData.of(GeoRegions.instance) : null;

    if (data != null) {
      // Land.
      final land = Path();
      final borders = Path();
      for (final ring in data.countries.at(step)) {
        if (ring.cap * r < 0.6) continue; // smaller than a pixel
        addRing(ring, area: land, outline: borders);
      }
      // The flat map's country style (MapBaseLayers: dark land, 1.1 px white
      // border), softened only below its zoom range, where the whole globe
      // shows and full-strength borders would crowd it.
      final b = ((ppd - 3) / (_flatMinPpd - 3)).clamp(0.0, 1.0);
      canvas
        ..drawPath(land, Paint()..color = MapBaseLayers.landColor)
        ..drawPath(
          borders,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6 + 0.5 * b
            ..color = MapBaseLayers.countryBorderColor.withValues(
              alpha: 0.55 + 0.45 * b,
            ),
        );

      // Province borders over the country lines (as on the flat map), fading
      // in towards its province zoom.
      final t = ((ppd - 2.5) / (_provincePpd - 2.5)).clamp(0.0, 1.0);
      if (t > 0) {
        final provinces = Path();
        for (final ring in data.provinces.at(step)) {
          if (ring.cap * r < 1.5) continue;
          addRing(ring, outline: provinces);
        }
        canvas.drawPath(
          provinces,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6
            ..color = MapBaseLayers.provinceBorderColor.withValues(
              alpha: 0.25 * t,
            ),
        );
      }
    }

    // Visited regions in the travel-map colour bands. Finer than the base so
    // small regions (a city) still show at globe scale.
    final visitedStep = math.min(step, 0.05);
    for (final entry in scene.visited.entries) {
      final area = Path();
      final outline = Path();
      for (final layer in entry.value) {
        for (final ring in layer.at(visitedStep)) {
          addRing(ring, area: area, outline: outline);
        }
      }
      // The flat map's style: 85% fill, 1 px white border.
      canvas
        ..drawPath(area, Paint()..color = entry.key.withValues(alpha: 0.85))
        ..drawPath(
          outline,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = AppColors.white,
        );
    }

    // Pins and names, in the replaced map's layer order — [TravelMap] puts
    // its names over its pins, the picker its pins over its names. Every pin,
    // place name, country and province name is drawn, overlapping or not,
    // exactly as there.
    final picker = scene.look == GlobeLook.picker;

    // Pins: that map's pin icon at every zoom. Each region's pins merge into
    // one until zoomed in (see [_pinsSplitZoom]), then slide apart; their
    // names show further in.
    void drawPins() {
      final glyph = _text(
        _GlobeScene.pinGlyph,
        picker ? _GlobeScene.pickerPinStyle : _GlobeScene.pinStyle,
      );
      final seenGlyph = _text(_GlobeScene.pinGlyph, _GlobeScene.seenPinStyle);
      final iconTop = picker ? _pickerPinIconTop : _pinIconTop;
      final nameTop = picker ? _pickerPinNameTop : _pinNameTop;
      void drawIcon(Offset at, {required bool dimmed}) {
        final g = dimmed ? seenGlyph : glyph;
        g.paint(canvas, at.translate(-g.width / 2, -iconTop));
      }

      final spread = Curves.easeOutCubic.transform(split?.value ?? 1);
      if (spread <= 0) {
        // One pin per region, dimmed only once all of its pins are.
        for (final group in scene.groups) {
          if (project(group.at) < 0.02 || !onScreen(60)) continue;
          drawIcon(
            Offset(px, py),
            dimmed: group.pins.every((pin) => seen.contains(pin.key)),
          );
        }
        return;
      }
      if (spread < 1) {
        // Mid-way: each pin slides between its region's merged pin and its
        // own place. Dimmed pins go first, so while they still overlap the
        // stack reads white whenever any of them is.
        for (final group in scene.groups) {
          final groupVisible = project(group.at) >= 0.02;
          final from = Offset(px, py);
          for (final dimmedPass in const [true, false]) {
            for (final pin in group.pins) {
              final dimmed = seen.contains(pin.key);
              if (dimmed != dimmedPass) continue;
              if (project(pin.at) < 0.02) continue;
              final to = Offset(px, py);
              final at = groupVisible ? Offset.lerp(from, to, spread)! : to;
              px = at.dx;
              py = at.dy;
              if (!onScreen(60)) continue;
              drawIcon(at, dimmed: dimmed);
            }
          }
        }
        return;
      }
      final names = _atZoom(camera.zoom, _pinNamesZoom);
      for (final pin in scene.pins) {
        if (project(pin.at) < 0.02 || !onScreen(60)) continue;
        final at = Offset(px, py);
        drawIcon(at, dimmed: seen.contains(pin.key));
        if (!names || pin.label.isEmpty) continue;
        final tp = _text(pin.label, scene.pinNameStyle, maxWidth: 96);
        tp.paint(canvas, at.translate(-tp.width / 2, -nameTop));
      }
    }

    // The flat map's FittedBox label: centred on [at], shrunk (never grown) to
    // fit a [w]×[h] box.
    void drawName(String text, Offset at, double w, double h, TextStyle style) {
      final tp = _text(text, style);
      if (tp.width <= 0 || tp.height <= 0) return;
      final s = math.min(1.0, math.min(w / tp.width, h / tp.height));
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..scale(s);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    void drawNames() {
      if (data == null) return;
      final lang = scene.lang;
      // Country names: appear once the country is wide enough on screen.
      for (final name in data.countryLabels) {
        final span = name.label.spanDeg * ppd;
        if (span < 55 || span > 900) continue;
        // Away from the rim, where the globe's edge would clip the word.
        if (project(name.at) < 0.4 || !onScreen(0)) continue;
        drawName(
          name.label.localizedName(lang).toUpperCase(),
          Offset(px, py),
          span.clamp(40, 150),
          (span * 0.5).clamp(16, 44),
          scene.countryStyle,
        );
      }

      // Province names: only when zoomed in, sized to each province.
      if (ppd < _provinceNamePpd) return;
      for (final name in data.regionLabels) {
        final w = name.widthDeg * ppd;
        if (w < 42) continue;
        if (project(name.at) < 0.4 || !onScreen(0)) continue;
        final region = name.region;
        // TravelMap: a pin named after its province would print the same
        // word twice, so that province gets the suffix too. The picker
        // always prints the display name (matching its search).
        final clashesWithPin =
            !picker &&
            !region.sharesNameWithCity &&
            (scene.pinNames.contains(region.name.trim().toLowerCase()) ||
                region.name.trim().toLowerCase() ==
                    region.countryName.trim().toLowerCase());
        final label = clashesWithPin
            ? (lang == 'ru'
                  ? '${region.localizedName(lang)} (регион)'
                  : '${region.localizedName(lang)} Region')
            : region.localizedDisplayName(lang);
        drawName(
          label,
          Offset(px, py),
          w.clamp(36, 140),
          (name.heightDeg * ppd * 0.7).clamp(14, 34),
          scene.provinceStyle,
        );
      }
    }

    if (picker) {
      drawNames();
      drawPins();
    } else {
      drawPins();
      drawNames();
    }

    if (edgeVisible) {
      canvas
        ..restore()
        // Sphere shading + rim on top.
        ..drawCircle(
          c,
          r,
          Paint()
            ..shader = const RadialGradient(
              center: Alignment(-0.4, -0.45),
              radius: 1.15,
              colors: [Color(0x14FFFFFF), Color(0x00000000), Color(0x73000000)],
              stops: [0, 0.5, 1],
            ).createShader(globe),
        )
        ..drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = const Color(0x2EFFFFFF),
        );
    }
  }

  /// A grid line through [lngLat]; the pen lifts behind the horizon.
  static void _addLine(
    Path path,
    List<Offset> lngLat,
    Offset c,
    double r,
    double cosL0,
    double sinL0,
    double cosP0,
    double sinP0,
  ) {
    var pen = false;
    for (final p in lngLat) {
      final la = p.dy * _deg;
      final lo = p.dx * _deg;
      final cl = math.cos(la);
      final x0 = cl * math.cos(lo);
      final y0 = cl * math.sin(lo);
      final z0 = math.sin(la);
      final a = x0 * cosL0 + y0 * sinL0;
      final z = sinP0 * z0 + cosP0 * a;
      if (z < 0) {
        pen = false;
        continue;
      }
      final x = c.dx + r * (y0 * cosL0 - x0 * sinL0);
      final y = c.dy - r * (cosP0 * z0 - sinP0 * a);
      if (pen) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        pen = true;
      }
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      !identical(old.camera, camera) ||
      !identical(old.scene, scene) ||
      !setEquals(old.seen, seen) ||
      old.padding != padding ||
      !identical(old.split, split);
}

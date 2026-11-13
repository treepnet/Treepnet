import 'dart:math' as math;

/// A point on the globe, in degrees. The maps used latlong2's for this type
/// only; the globe draws itself.
class LatLng {
  const LatLng(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// The box between two corners on the globe, in degrees, whichever way round
/// they are given (as flutter_map's, which it replaces).
class LatLngBounds {
  LatLngBounds(LatLng a, LatLng b)
    : north = math.max(a.latitude, b.latitude),
      south = math.min(a.latitude, b.latitude),
      east = math.max(a.longitude, b.longitude),
      west = math.min(a.longitude, b.longitude);

  final double north;
  final double south;
  final double east;
  final double west;
}

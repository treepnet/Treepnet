/// A pin on a travel globe: a post's spot (with its [postId] and its small
/// photo, [thumb]) or a story pin's (no post, no photo).
typedef TravelPin = ({
  String? postId,
  double lat,
  double lng,
  String? name,
  String? thumb,
});

/// What a person's travel globe shows, from the server (`travel_maps`): the
/// regions coloured — region iso to how many things are there — and the
/// pins.
class TravelMap {
  const TravelMap({required this.regions, required this.pins});

  /// From a `travel_maps` row.
  factory TravelMap.fromRow(Map<String, dynamic> row) {
    final regions = <String, int>{};
    final rawRegions = row['regions'];
    if (rawRegions is Map) {
      for (final MapEntry(:key, :value) in rawRegions.entries) {
        if (value is num) regions[key.toString()] = value.toInt();
      }
    }
    final pins = <TravelPin>[];
    final rawPins = row['points'];
    if (rawPins is List) {
      for (final p in rawPins.whereType<Map<dynamic, dynamic>>()) {
        final lat = p['lat'];
        final lng = p['lng'];
        if (lat is! num || lng is! num) continue;
        final thumb = p['thumb'];
        pins.add((
          postId: p['post_id'] as String?,
          lat: lat.toDouble(),
          lng: lng.toDouble(),
          name: p['name'] as String?,
          // From migration 041 on; none before it.
          thumb: thumb is String && thumb.isNotEmpty ? thumb : null,
        ));
      }
    }
    return TravelMap(regions: regions, pins: pins);
  }

  final Map<String, int> regions;
  final List<TravelPin> pins;

  /// The spot of the post [postId], if it has one.
  TravelPin? pinOf(String postId) {
    for (final pin in pins) {
      if (pin.postId == postId) return pin;
    }
    return null;
  }

  /// The pins as the globe takes them.
  List<({double lat, double lng, String? name})> get points => [
    for (final pin in pins) (lat: pin.lat, lng: pin.lng, name: pin.name),
  ];
}

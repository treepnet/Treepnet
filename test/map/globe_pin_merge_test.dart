import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/globe_view.dart';

/// Where the zoomed-out globe draws a spot's pin: its region's pins merge
/// into one at their middle (the new feed's small card stands on it).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => GeoRegions.instance.load());

  const a = (lat: 41.31, lng: 69.28, name: null);
  const b = (lat: 41.33, lng: 69.24, name: null);
  const samarkand = (lat: 39.65, lng: 66.96, name: null);

  test('the middle of its region’s spots, each spot once', () {
    expect(GeoRegions.instance.regionAt(a.lng, a.lat)?.iso, 'UZ-TK');
    expect(GeoRegions.instance.regionAt(b.lng, b.lat)?.iso, 'UZ-TK');
    final at = GlobeView.zoomedOutPinOf(
      // The same spot twice is one pin; Samarkand is another region's.
      [a, a, a, b, samarkand],
      (lat: a.lat, lng: a.lng),
    );
    expect(at.lat, closeTo(41.32, 0.001));
    expect(at.lng, closeTo(69.26, 0.001));
  });

  test('alone in its region, or out at sea: the spot itself', () {
    expect(GlobeView.zoomedOutPinOf([a, samarkand], (lat: 39.65, lng: 66.96)), (
      lat: 39.65,
      lng: 66.96,
    ));
    expect(
      GlobeView.zoomedOutPinOf(
        [a, (lat: 40.0, lng: -40.0, name: null)],
        (lat: 40.0, lng: -40.0),
      ),
      (lat: 40.0, lng: -40.0),
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/user_profile/widgets/user_profile_travel_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => GeoRegions.instance.load());

  test('each country once, every region', () {
    final counts = travelCounts({
      'UZ-TK': 3, // Tashkent
      'UZ-SA': 1, // Samarqand
      'TR-34': 2, // Istanbul
    });
    expect(counts.countries, 2);
    expect(counts.regions, 3);
  });

  test('nothing visited', () {
    final counts = travelCounts(const {});
    expect(counts.countries, 0);
    expect(counts.regions, 0);
  });
}

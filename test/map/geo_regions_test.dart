import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => GeoRegions.instance.load());

  test('a province named after its capital is suffixed, the city is not', () {
    final region = GeoRegions.instance.regionByIso('UZ-TO');
    final city = GeoRegions.instance.regionByIso('UZ-TK');
    expect(region, isNotNull, reason: 'Tashkent Region missing from the index');
    expect(city, isNotNull, reason: 'Tashkent City missing from the index');
    expect(region!.name, 'Tashkent');
    expect(city!.name, 'Tashkent');
    expect(region.displayName, 'Tashkent Region');
    expect(city.displayName, 'Tashkent');
  });

  test('same-sized neighbours sharing a name are left alone', () {
    final a = GeoRegions.instance.regionByIso('RU-ALT');
    final b = GeoRegions.instance.regionByIso('RU-AL');
    expect(a?.displayName, 'Altai Republic');
    expect(b?.displayName, 'Altai Republic');
  });

  test('France is labelled on its mainland, not out in the Atlantic', () {
    final france = GeoRegions.instance.countryLabels
        .where((c) => c.name == 'France')
        .firstOrNull;
    expect(france, isNotNull);
    expect(france!.center.dx, closeTo(2.5, 2));
    expect(france.center.dy, closeTo(46.5, 2));
  });
}

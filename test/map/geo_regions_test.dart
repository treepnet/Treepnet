import 'dart:convert';
import 'dart:io';

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

  test('every region code is one region, listed once', () {
    final codes = [
      for (final country in GeoRegions.instance.countries)
        for (final region in country.regions) region.iso,
    ];
    expect(codes.toSet().length, codes.length);
    // Shapes the source filed under another code, now their own.
    expect(GeoRegions.instance.regionByIso('CO-DC')?.nameEn, 'Bogotá');
    expect(GeoRegions.instance.regionByIso('KZ-ALM')?.nameRu,
        'Алматинская область');
    expect(GeoRegions.instance.regionByIso('KZ-ALA')?.nameEn, 'Almaty');
    expect(GeoRegions.instance.regionByIso('AU-NSW')?.nameEn,
        'New South Wales');
    expect(GeoRegions.instance.regionByIso('BA-09')?.nameEn, 'Sarajevo');
  });

  test('France is labelled on its mainland, not out in the Atlantic', () {
    final france = GeoRegions.instance.countryLabels
        .where((c) => c.name == 'France')
        .firstOrNull;
    expect(france, isNotNull);
    expect(france!.center.dx, closeTo(2.5, 2));
    expect(france.center.dy, closeTo(46.5, 2));
  });

  // The app loads assets/geo/world_geo.bin, packed from the GeoJSON next to
  // it by scripts/build_geo_bin.py. Re-run that after editing the JSON.
  test('world_geo.bin matches its GeoJSON sources', () {
    // + 0.0 turns the JSON's -0.0 into 0.0, the one thing the packing changes.
    String point(Object? p) {
      final xy = p! as List;
      return '${(xy[0] as num).toDouble() + 0.0},'
          '${(xy[1] as num).toDouble() + 0.0}';
    }
    String offset(Offset p) => '${p.dx + 0.0},${p.dy + 0.0}';
    String ring(Iterable<String> points) => points.join(' ');

    final base = json.decode(
      File('assets/geo/world_countries.min.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      [for (final r in GeoRegions.instance.countryRings) ring(r.map(offset))],
      [for (final r in base['rings'] as List) ring((r as List).map(point))],
    );

    final admin = json.decode(
      File('assets/geo/world_admin1.min.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final expected = <String>[];
    for (final feature in admin['features'] as List) {
      final props = (feature as Map)['properties'] as Map;
      final geometry = feature['geometry'] as Map;
      final coords = geometry['coordinates'] as List;
      final rings = geometry['type'] == 'Polygon'
          ? coords
          : [for (final polygon in coords) ...polygon as List];
      expected.add(
        [
          props['iso'],
          props['name'] ?? props['iso'],
          props['en'],
          props['ru'],
          props['cc'],
          props['admin'],
          for (final r in rings) ring((r as List).map(point)),
        ].join('|'),
      );
    }
    final actual = [
      for (final country in GeoRegions.instance.countries)
        for (final region in country.regions)
          [
            region.iso,
            region.name,
            region.nameEn,
            region.nameRu,
            region.countryCode,
            region.countryName,
            for (final r in region.rings) ring(r.map(offset)),
          ].join('|'),
    ];
    expect(actual..sort(), expected..sort());
  });
}

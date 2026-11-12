import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';

GeoRegion _region(List<List<Offset>> rings) => GeoRegion(
  iso: 'XX-1',
  name: 'Bukhara',
  nameEn: 'Bukhara',
  nameRu: 'Бухарская область',
  countryCode: 'UZ',
  countryName: 'Uzbekistan',
  countryNameRu: 'Узбекистан',
  rings: rings,
);

void main() {
  group('GeoRegion.centroidLngLat', () {
    test('a C-shaped region: the anchor is inside it, not in the gap', () {
      // Dense points along the outer edge pull the vertices' mean into the
      // open middle of the C.
      final c = <Offset>[
        for (var i = 0; i <= 40; i++) Offset(i / 4, 0),
        const Offset(10, 2),
        const Offset(2, 2),
        const Offset(2, 8),
        const Offset(10, 8),
        const Offset(10, 10),
        for (var i = 40; i >= 0; i--) Offset(i / 4, 10),
      ];
      final region = _region([c]);
      expect(region.containsLngLat(region.centroidLngLat), isTrue);
    });

    test('a simple square keeps its middle', () {
      final region = _region([
        const [Offset(0, 0), Offset(4, 0), Offset(4, 4), Offset(0, 4)],
      ]);
      expect(region.centroidLngLat, const Offset(2, 2));
    });

    test('a hole counts as outside', () {
      final region = _region([
        const [Offset(0, 0), Offset(10, 0), Offset(10, 10), Offset(0, 10)],
        const [Offset(4, 4), Offset(6, 4), Offset(6, 6), Offset(4, 6)],
      ]);
      expect(region.containsLngLat(const Offset(5, 5)), isFalse);
      expect(region.containsLngLat(const Offset(1, 1)), isTrue);
    });
  });

  group('GeoRegion.isOwnName', () {
    final region = _region(const []);

    test('its names in any language and form', () {
      for (final text in [
        'Bukhara',
        ' bukhara ',
        'Бухарская область',
        'Bukhara, Uzbekistan',
        'Бухарская область, Узбекистан',
      ]) {
        expect(region.isOwnName(text), isTrue, reason: text);
      }
    });

    test('a name the author gave is not', () {
      for (final text in ['Ark of Bukhara', 'Lyabi-Hauz', '', 'Samarkand']) {
        expect(region.isOwnName(text), isFalse, reason: text);
      }
    });
  });

  testWidgets('every region of the real map has its anchor inside it', (
    tester,
  ) async {
    await tester.runAsync(() => GeoRegions.instance.load());
    final outside = <String>[];
    for (final country in GeoRegions.instance.countries) {
      for (final region in country.regions) {
        if (region.rings.every((r) => r.length < 3)) continue;
        if (!region.containsLngLat(region.centroidLngLat)) {
          outside.add(region.iso);
        }
      }
    }
    expect(outside, isEmpty);
    final qr = GeoRegions.instance.regionByIso('UZ-QR')!;
    final ng = GeoRegions.instance.regionByIso('UZ-NG')!;
    expect(qr.containsLngLat(qr.centroidLngLat), isTrue);
    expect(ng.containsLngLat(ng.centroidLngLat), isTrue);
  });
}

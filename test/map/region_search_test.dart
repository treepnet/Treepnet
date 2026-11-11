import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/region_search.dart';

GeoRegion _region(
  String iso,
  String name, {
  String nameRu = '',
  String country = 'Uzbekistan',
  String countryRu = 'Узбекистан',
}) => GeoRegion(
  iso: iso,
  name: name,
  nameEn: name,
  nameRu: nameRu,
  countryCode: iso.split('-').first,
  countryName: country,
  countryNameRu: countryRu,
  rings: const [],
);

bool _finds(GeoRegion region, String typed) =>
    regionMatchesSearch(region, normalizeSearch(typed));

void main() {
  final bukhara = _region('UZ-BU', 'Bukhara', nameRu: 'Бухарская область');
  final fergana = _region('UZ-FA', 'Fergana', nameRu: 'Ферганская область');
  final tashkentRegion = _region('UZ-TO', 'Tashkent');

  test('Uzbek names find the region, in Latin and Cyrillic', () {
    expect(_finds(bukhara, 'Buxoro'), isTrue);
    expect(_finds(bukhara, 'бухоро'), isTrue);
    expect(_finds(tashkentRegion, 'toshkent vil'), isTrue);
  });

  test('every way of writing the Uzbek apostrophe works', () {
    for (final typed in ["Farg'ona", 'Fargʻona', 'Farg’ona', 'Fargona']) {
      expect(_finds(fergana, typed), isTrue, reason: typed);
    }
  });

  test('a word inside the name matches, not only its start', () {
    expect(_finds(bukhara, 'област'), isTrue);
    expect(_finds(bukhara, 'ukhara'), isFalse);
  });

  test('the country, also by its Uzbek name', () {
    expect(_finds(bukhara, 'Oʻzbekiston'), isTrue);
    expect(_finds(bukhara, 'uzbek'), isTrue);
    final istanbul = _region(
      'TR-34',
      'Istanbul',
      country: 'Turkey',
      countryRu: 'Турция',
    );
    expect(_finds(istanbul, 'Turkiya'), isTrue);
  });

  test('nothing typed finds nothing', () {
    expect(_finds(bukhara, '  '), isFalse);
  });

  test('a query never runs from one name into the next', () {
    final region = _region('US-NY', 'Big New', country: 'York');
    expect(_finds(region, 'new'), isTrue);
    expect(_finds(region, 'york'), isTrue);
    expect(_finds(region, 'new york'), isFalse);
  });

  group('over the real index', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(prepareRegionSearch);

    List<String> search(String typed) => [
      for (final region in GeoRegions.instance.allRegions)
        if (regionMatchesSearch(region, normalizeSearch(typed))) region.iso,
    ];

    test('finds places by any of their names', () {
      expect(search('samarq'), contains('UZ-SA'));
      expect(search('Buxoro'), contains('UZ-BU'));
      expect(search('москва'), contains('RU-MOS'));
    });

    test('a search over every region takes well under a frame', () {
      final watch = Stopwatch()..start();
      search('zzqx');
      watch.stop();
      // It was 126–192 ms when every name was normalized per keystroke.
      expect(watch.elapsedMilliseconds, lessThan(40));
    });
  });
}

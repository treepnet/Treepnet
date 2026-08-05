import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/view/location_posts_page.dart';

/// The page rebuilds itself from the URL, because GoRouter drops `extra` on a
/// rebuild. That makes the query string the page's real input — including when
/// it is malformed.
void main() {
  group('LocationPostsPage.fromQuery', () {
    test('a pin tap keeps its coordinates', () {
      final page = LocationPostsPage.fromQuery(const {
        'userId': 'u1',
        'iso': 'UZ-TK',
        'name': 'Tashkent',
        'country': 'Uzbekistan',
        'scope': 'point',
        'lat': '41.31',
        'lng': '69.24',
      });

      expect(page.scope, LocationPostsScope.point);
      expect(page.lat, 41.31);
      expect(page.lng, 69.24);
      expect(page.regionIso, 'UZ-TK');
      expect(page.countryName, 'Uzbekistan');
    });

    test('a region tap needs no coordinates', () {
      final page = LocationPostsPage.fromQuery(const {
        'userId': 'u1',
        'iso': 'UZ-TK',
        'name': 'Tashkent',
        'scope': 'region',
      });

      expect(page.scope, LocationPostsScope.region);
      expect(page.lat, isNull);
    });

    test('falls back to the region when a point has no coordinates', () {
      // Would otherwise reach `lat!` in the query and crash the page.
      final page = LocationPostsPage.fromQuery(const {
        'userId': 'u1',
        'iso': 'UZ-TK',
        'name': 'Tashkent',
        'scope': 'point',
      });

      expect(page.scope, LocationPostsScope.region);
    });

    test('falls back to the region when the coordinates are not numbers', () {
      final page = LocationPostsPage.fromQuery(const {
        'userId': 'u1',
        'iso': 'UZ-TK',
        'name': 'Tashkent',
        'scope': 'point',
        'lat': 'north',
        'lng': 'east',
      });

      expect(page.scope, LocationPostsScope.region);
      expect(page.lat, isNull);
    });

    test('an unknown scope is treated as a region', () {
      final page = LocationPostsPage.fromQuery(const {
        'userId': 'u1',
        'iso': 'UZ-TK',
        'name': 'Tashkent',
        'scope': 'galaxy',
      });

      expect(page.scope, LocationPostsScope.region);
    });

    test('survives an empty query instead of throwing', () {
      final page = LocationPostsPage.fromQuery(const {});

      expect(page.scope, LocationPostsScope.region);
      expect(page.userId, isEmpty);
    });
  });
}

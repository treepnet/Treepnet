import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/stories/view/story_place_label.dart';

GeoRegion _region({bool sharesNameWithCity = false}) => GeoRegion(
  iso: 'UZ-TO',
  name: 'Tashkent',
  nameEn: 'Tashkent',
  nameRu: 'Ташкентская область',
  countryCode: 'UZ',
  countryName: 'Uzbekistan',
  countryNameRu: 'Узбекистан',
  rings: const [],
)..sharesNameWithCity = sharesNameWithCity;

void main() {
  test('the place is written in the app language', () {
    expect(storyPlaceLabel(_region(), 'ru'), 'Ташкентская область, Узбекистан');
    expect(storyPlaceLabel(_region(), 'en'), 'Tashkent, Uzbekistan');
  });

  test('a province named after its city says so, as on the map', () {
    expect(
      storyPlaceLabel(_region(sharesNameWithCity: true), 'en'),
      'Tashkent Region, Uzbekistan',
    );
  });
}

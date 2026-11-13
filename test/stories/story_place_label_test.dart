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

  test('a territory that is its own country is named once', () {
    final baikonur = GeoRegion(
      iso: '-99-X05~',
      name: 'Baikonur',
      nameEn: 'Baikonur',
      nameRu: 'Байконур',
      countryCode: '-1',
      countryName: 'Baykonur Cosmodrome',
      countryNameRu: 'Байконур',
      rings: const [],
    );
    expect(storyPlaceLabel(baikonur, 'ru'), 'Байконур');
  });
}

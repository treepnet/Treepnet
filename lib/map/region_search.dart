import 'package:flutter/foundation.dart';
import 'package:treepnet/map/geo_regions.dart';

/// Matching a typed query against regions in the place search.
///
/// The map data names regions in English and Russian only, so "Buxoro" or
/// "Fargʻona" found nothing. Uzbekistan's regions and the countries people
/// travel to most also answer to their Uzbek names (Latin and Cyrillic) here.
/// These are only for matching what's typed — nothing in the app is shown in
/// Uzbek.
const Map<String, List<String>> _uzRegionNames = {
  'UZ-TK': ['Toshkent shahri', 'Тошкент шаҳри'],
  'UZ-TO': ['Toshkent viloyati', 'Тошкент вилояти'],
  'UZ-AN': ['Andijon', 'Андижон'],
  'UZ-BU': ['Buxoro', 'Бухоро'],
  'UZ-FA': ['Fargʻona', 'Фарғона'],
  'UZ-JI': ['Jizzax', 'Жиззах'],
  'UZ-NG': ['Namangan', 'Наманган'],
  'UZ-NW': ['Navoiy', 'Навоий'],
  'UZ-QA': ['Qashqadaryo', 'Қашқадарё'],
  'UZ-QR': ['Qoraqalpogʻiston', 'Қорақалпоғистон'],
  'UZ-SA': ['Samarqand', 'Самарқанд'],
  'UZ-SI': ['Sirdaryo', 'Сирдарё'],
  'UZ-SU': ['Surxondaryo', 'Сурхондарё'],
  'UZ-XO': ['Xorazm', 'Хоразм'],
};

const Map<String, List<String>> _uzCountryNames = {
  'UZ': ['Oʻzbekiston', 'Ўзбекистон'],
  'KZ': ['Qozogʻiston', 'Қозоғистон'],
  'KG': ['Qirgʻiziston', 'Қирғизистон'],
  'TJ': ['Tojikiston', 'Тожикистон'],
  'TM': ['Turkmaniston', 'Туркманистон'],
  'AF': ['Afgʻoniston', 'Афғонистон'],
  'RU': ['Rossiya', 'Россия'],
  'TR': ['Turkiya', 'Туркия'],
  'AE': ['Birlashgan Arab Amirliklari', 'BAA', 'Бирлашган Араб Амирликлари'],
  'SA': ['Saudiya Arabistoni', 'Саудия Арабистони'],
  'EG': ['Misr', 'Миср'],
  'GE': ['Gruziya', 'Грузия'],
  'AZ': ['Ozarbayjon', 'Озарбайжон'],
  'IR': ['Eron', 'Эрон'],
  'CN': ['Xitoy', 'Хитой'],
  'KR': ['Janubiy Koreya', 'Жанубий Корея'],
  'JP': ['Yaponiya', 'Япония'],
  'IN': ['Hindiston', 'Ҳиндистон'],
  'TH': ['Tailand', 'Таиланд'],
  'MY': ['Malayziya', 'Малайзия'],
  'ID': ['Indoneziya', 'Индонезия'],
  'DE': ['Germaniya', 'Германия'],
  'FR': ['Fransiya', 'Франция'],
  'IT': ['Italiya', 'Италия'],
  'ES': ['Ispaniya', 'Испания'],
  'GB': ['Buyuk Britaniya', 'Angliya', 'Буюк Британия'],
  'US': ['AQSH', 'Amerika', 'АҚШ', 'Америка'],
};

/// Lower case, the apostrophes of Uzbek Latin dropped (ʻ ’ ' ` all written
/// for the same letter), ё read as е, and anything that isn't a letter or a
/// digit turned into a single space.
String normalizeSearch(String text) => text
    .toLowerCase()
    .replaceAll(RegExp("['`ʻʼ’‘ʹ]"), '')
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// Every name a region answers to: its own and its country's, in English,
/// Russian and Uzbek.
List<String> _namesOf(GeoRegion region) => [
  region.name,
  region.nameEn,
  region.nameRu,
  region.countryName,
  region.countryNameRu,
  ...?_uzRegionNames[region.iso],
  ...?_uzCountryNames[region.countryCode],
];

/// [names] normalized, one per line, each line starting with a space: `' q'`
/// then finds the start of any word, and a query (it never has a line break)
/// can't run from one name into the next.
String _searchTextOf(List<String> names) =>
    names.map((name) => ' ${normalizeSearch(name)}').join('\n');

List<String> _searchTextsOf(List<List<String>> names) => [
  for (final regionNames in names) _searchTextOf(regionNames),
];

/// Each region's [_searchTextOf], made once. Normalizing 5–7 names of all
/// 4,499 regions again on every keystroke took 0.1–0.2 s on a Mac and froze
/// typing on mid-range phones; over the prepared text a search is ~1 ms.
final _searchText = Expando<String>('regionSearchText');

/// Prepares the search text of every region on a background isolate, so the
/// first letter typed doesn't pay for it either. Call when a screen with a
/// region search opens; searching before it's done still works.
Future<void> prepareRegionSearch() async {
  await GeoRegions.instance.load();
  final regions = [
    for (final region in GeoRegions.instance.allRegions)
      if (_searchText[region] == null) region,
  ];
  if (regions.isEmpty) return;
  final texts = await compute(_searchTextsOf, [
    for (final region in regions) _namesOf(region),
  ]);
  for (var i = 0; i < regions.length; i++) {
    _searchText[regions[i]] ??= texts[i];
  }
}

/// Whether [region] matches [query] (already [normalizeSearch]ed): the start
/// of any word of its name or its country's, in English, Russian or Uzbek.
bool regionMatchesSearch(GeoRegion region, String query) {
  if (query.isEmpty) return false;
  final text = _searchText[region] ??= _searchTextOf(_namesOf(region));
  return text.contains(' $query');
}

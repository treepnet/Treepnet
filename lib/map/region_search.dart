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

/// Other names a region answers to: the usual English spellings of
/// Uzbekistan's regions (the data spells them the Uzbek way: Samarqand,
/// Xorazm, Qashqadaryo), and the best-known cities inside a region, which the
/// data doesn't name (Khiva is in Xorazm, Mecca in the Makkah province, Kazan
/// in Tatarstan). Typing them found nothing.
const Map<String, List<String>> _otherRegionNames = {
  'UZ-SA': ['Samarkand'],
  'UZ-XO': [
    'Khorezm',
    'Khorazm',
    'Khiva',
    'Xiva',
    'Хива',
    'Urgench',
    'Urganch',
    'Ургенч',
  ],
  'UZ-QA': [
    'Kashkadarya',
    'Qarshi',
    'Karshi',
    'Карши',
    'Shahrisabz',
    'Шахрисабз',
  ],
  'UZ-SU': ['Surkhandarya', 'Termez', 'Termiz', 'Термез'],
  'UZ-SI': ['Syrdarya', 'Gulistan', 'Guliston', 'Гулистан'],
  'UZ-FA': ['Kokand', 'Qoʻqon', 'Коканд', 'Margilan', 'Margʻilon', 'Маргилан'],
  'UZ-QR': ['Nukus', 'Нукус'],
  'KZ-ALA': ['Алматы', 'Olmaota', 'Олмаота'],
  'SA-02': ['Mecca', 'Makka', 'Макка'],
  'SA-03': ['Medina', 'Madina', 'Мадина'],
  'RU-TA': ['Kazan', 'Казань', 'Qozon', 'Қозон'],
  'GE-AJ': ['Batumi', 'Батуми'],
  'EG-BA': ['Hurghada', 'Хургада', 'Xurgada'],
  'EG-JS': [
    'Sharm el-Sheikh',
    'Шарм-эль-Шейх',
    'Sharm ash-Shayx',
    'Dahab',
    'Дахаб',
  ],
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
/// for the same letter), ё read as е, a stress mark dropped (the data's
/// Russian name of Somaliland has one), and anything else that isn't a letter
/// or a digit turned into a single space.
String normalizeSearch(String text) => text
    .toLowerCase()
    .replaceAll(RegExp("['`ʻʼ’‘ʹ\u0301]"), '')
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

typedef _Names = ({List<String> own, List<String> country});
typedef _SearchText = ({String own, String country});

/// The names a region answers to: its own (in English, Russian and Uzbek, and
/// [_otherRegionNames]) and, apart, its country's.
_Names _namesOf(GeoRegion region) => (
  own: [
    region.name,
    region.nameEn,
    region.nameRu,
    ...?_uzRegionNames[region.iso],
    ...?_otherRegionNames[region.iso],
  ],
  country: [
    region.countryName,
    region.countryNameRu,
    ...?_uzCountryNames[region.countryCode],
  ],
);

/// [names] normalized, one per line, each line starting with a space: `' q'`
/// then finds the start of any word, and a query (it never has a line break)
/// can't run from one name into the next.
String _textOf(List<String> names) =>
    names.map((name) => ' ${normalizeSearch(name)}').join('\n');

_SearchText _searchTextOf(_Names names) =>
    (own: _textOf(names.own), country: _textOf(names.country));

List<_SearchText> _searchTextsOf(List<_Names> names) => [
  for (final regionNames in names) _searchTextOf(regionNames),
];

/// Each region's search text, made once. Normalizing 5–7 names of all 4,499
/// regions again on every keystroke took 0.1–0.2 s on a Mac and froze typing
/// on mid-range phones; over the prepared text a search is ~1 ms.
final _searchText = Expando<_SearchText>('regionSearchText');

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

/// [query] without the last letter of its last word, when that looks like an
/// ending: the Russian data names a region by an adjective (Бухарская
/// область), so the noun typed in full (бухара, фергана, кашкадарья) wasn't
/// the start of any word, and what showed for "бух" vanished at "бухара".
String? _stemOf(String query) {
  final last = query.substring(query.lastIndexOf(' ') + 1);
  if (last.length < 4 || !RegExp(r'[аяьыиеуйay]$').hasMatch(last)) {
    return null;
  }
  return query.substring(0, query.length - 1);
}

/// How well [region] matches [query] and its [stem] (lower is better), or
/// null for not at all: its own name before its country's, the query as typed
/// before its stem.
int? _rankOf(GeoRegion region, String query, String? stem) {
  final text = _searchText[region] ??= _searchTextOf(_namesOf(region));
  if (text.own.contains(' $query')) return 0;
  if (stem != null && text.own.contains(' $stem')) return 1;
  if (text.country.contains(' $query')) return 2;
  if (stem != null && text.country.contains(' $stem')) return 3;
  return null;
}

/// Whether [region] matches [query] (already [normalizeSearch]ed): the start
/// of any word of its name or its country's, in English, Russian or Uzbek.
bool regionMatchesSearch(GeoRegion region, String query) {
  if (query.isEmpty) return false;
  return _rankOf(region, query, _stemOf(query)) != null;
}

/// The regions [query] (already [normalizeSearch]ed) finds, best first, at
/// most [limit]: a match of the place's own name before one of its country's,
/// the query as typed before its stem. It used to be the first [limit]
/// matches in map order, so a country's regions could crowd out the place.
List<GeoRegion> searchRegions(String query, {required int limit}) {
  if (query.isEmpty) return const [];
  final stem = _stemOf(query);
  final byRank = List.generate(4, (_) => <GeoRegion>[]);
  for (final region in GeoRegions.instance.allRegions) {
    final rank = _rankOf(region, query, stem);
    if (rank != null) byRank[rank].add(region);
  }
  return byRank.expand((regions) => regions).take(limit).toList();
}

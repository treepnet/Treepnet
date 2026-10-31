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

/// Whether [region] matches [query] (already [normalizeSearch]ed): the start
/// of any word of its name or its country's, in English, Russian or Uzbek.
bool regionMatchesSearch(GeoRegion region, String query) {
  if (query.isEmpty) return false;
  bool hit(String name) => ' ${normalizeSearch(name)}'.contains(' $query');
  return hit(region.name) ||
      hit(region.nameEn) ||
      hit(region.nameRu) ||
      hit(region.countryName) ||
      hit(region.countryNameRu) ||
      (_uzRegionNames[region.iso]?.any(hit) ?? false) ||
      (_uzCountryNames[region.countryCode]?.any(hit) ?? false);
}

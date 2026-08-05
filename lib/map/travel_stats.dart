import 'package:treepnet/map/geo_regions.dart';

/// A gamified summary of a user's travels, derived from the ISO 3166-2 regions
/// they've posted from.
class TravelStats {
  const TravelStats({
    required this.regions,
    required this.countries,
    required this.continents,
    required this.worldPercent,
    required this.level,
    required this.levelEmoji,
    required this.nextLevelAt,
  });

  /// Builds stats from a set of visited ISO 3166-2 region codes.
  factory TravelStats.fromVisited(Set<String> visitedIso) {
    final countryCodes = <String>{};
    for (final iso in visitedIso) {
      final region = GeoRegions.instance.regionByIso(iso);
      if (region != null && region.countryCode.isNotEmpty) {
        countryCodes.add(region.countryCode);
      }
    }
    final continents = <String>{};
    for (final cc in countryCodes) {
      final continent = countryContinents[cc];
      if (continent != null) continents.add(continent);
    }

    final countryCount = countryCodes.length;
    // 171 sovereign countries in the bundled dataset.
    final percent = (countryCount / 171 * 100);

    final (level, emoji, next) = _level(countryCount);

    return TravelStats(
      regions: visitedIso.length,
      countries: countryCount,
      continents: continents.length,
      worldPercent: percent,
      level: level,
      levelEmoji: emoji,
      nextLevelAt: next,
    );
  }

  final int regions;
  final int countries;
  final int continents;
  final double worldPercent;
  /// Stable key (see [_level]); localise it before showing it to anyone.
  final String level;
  final String levelEmoji;

  /// Number of countries needed to reach the next level (0 if maxed).
  final int nextLevelAt;

  /// Returns a stable key rather than a display name: this is a model, and
  /// the label it maps to depends on the reader's language.
  static (String, String, int) _level(int countries) {
    if (countries >= 30) return ('legendary', '👑', 0);
    if (countries >= 20) return ('worldWanderer', '🌏', 30);
    if (countries >= 10) return ('globetrotter', '🌍', 20);
    if (countries >= 5) return ('experienced', '✈️', 10);
    if (countries >= 2) return ('explorer', '🧭', 5);
    if (countries >= 1) return ('new', '🌱', 2);
    return ('start', '📍', 1);
  }
}

/// ISO 3166-1 alpha-2 country code → continent (from Natural Earth admin-0).
const Map<String, String> countryContinents = {
  'AE': 'Asia',
  'AF': 'Asia',
  'AL': 'Europe',
  'AM': 'Asia',
  'AO': 'Africa',
  'AQ': 'Antarctica',
  'AR': 'South America',
  'AT': 'Europe',
  'AU': 'Oceania',
  'AZ': 'Asia',
  'BA': 'Europe',
  'BD': 'Asia',
  'BE': 'Europe',
  'BF': 'Africa',
  'BG': 'Europe',
  'BI': 'Africa',
  'BJ': 'Africa',
  'BN': 'Asia',
  'BO': 'South America',
  'BR': 'South America',
  'BS': 'North America',
  'BT': 'Asia',
  'BW': 'Africa',
  'BY': 'Europe',
  'BZ': 'North America',
  'CA': 'North America',
  'CD': 'Africa',
  'CF': 'Africa',
  'CG': 'Africa',
  'CH': 'Europe',
  'CI': 'Africa',
  'CL': 'South America',
  'CM': 'Africa',
  'CN': 'Asia',
  'CN-TW': 'Asia',
  'CO': 'South America',
  'CR': 'North America',
  'CU': 'North America',
  'CY': 'Asia',
  'CZ': 'Europe',
  'DE': 'Europe',
  'DJ': 'Africa',
  'DK': 'Europe',
  'DO': 'North America',
  'DZ': 'Africa',
  'EC': 'South America',
  'EE': 'Europe',
  'EG': 'Africa',
  'EH': 'Africa',
  'ER': 'Africa',
  'ES': 'Europe',
  'ET': 'Africa',
  'FI': 'Europe',
  'FJ': 'Oceania',
  'FK': 'South America',
  'GA': 'Africa',
  'GB': 'Europe',
  'GE': 'Asia',
  'GH': 'Africa',
  'GL': 'North America',
  'GM': 'Africa',
  'GN': 'Africa',
  'GQ': 'Africa',
  'GR': 'Europe',
  'GT': 'North America',
  'GW': 'Africa',
  'GY': 'South America',
  'HN': 'North America',
  'HR': 'Europe',
  'HT': 'North America',
  'HU': 'Europe',
  'ID': 'Asia',
  'IE': 'Europe',
  'IL': 'Asia',
  'IN': 'Asia',
  'IQ': 'Asia',
  'IR': 'Asia',
  'IS': 'Europe',
  'IT': 'Europe',
  'JM': 'North America',
  'JO': 'Asia',
  'JP': 'Asia',
  'KE': 'Africa',
  'KG': 'Asia',
  'KH': 'Asia',
  'KP': 'Asia',
  'KR': 'Asia',
  'KW': 'Asia',
  'KZ': 'Asia',
  'LA': 'Asia',
  'LB': 'Asia',
  'LK': 'Asia',
  'LR': 'Africa',
  'LS': 'Africa',
  'LT': 'Europe',
  'LU': 'Europe',
  'LV': 'Europe',
  'LY': 'Africa',
  'MA': 'Africa',
  'MD': 'Europe',
  'ME': 'Europe',
  'MG': 'Africa',
  'MK': 'Europe',
  'ML': 'Africa',
  'MM': 'Asia',
  'MN': 'Asia',
  'MR': 'Africa',
  'MW': 'Africa',
  'MX': 'North America',
  'MY': 'Asia',
  'MZ': 'Africa',
  'NA': 'Africa',
  'NC': 'Oceania',
  'NE': 'Africa',
  'NG': 'Africa',
  'NI': 'North America',
  'NL': 'Europe',
  'NP': 'Asia',
  'NZ': 'Oceania',
  'OM': 'Asia',
  'PA': 'North America',
  'PE': 'South America',
  'PG': 'Oceania',
  'PH': 'Asia',
  'PK': 'Asia',
  'PL': 'Europe',
  'PR': 'North America',
  'PS': 'Asia',
  'PT': 'Europe',
  'PY': 'South America',
  'QA': 'Asia',
  'RO': 'Europe',
  'RS': 'Europe',
  'RU': 'Europe',
  'RW': 'Africa',
  'SA': 'Asia',
  'SB': 'Oceania',
  'SD': 'Africa',
  'SE': 'Europe',
  'SI': 'Europe',
  'SK': 'Europe',
  'SL': 'Africa',
  'SN': 'Africa',
  'SO': 'Africa',
  'SR': 'South America',
  'SS': 'Africa',
  'SV': 'North America',
  'SY': 'Asia',
  'SZ': 'Africa',
  'TD': 'Africa',
  'TG': 'Africa',
  'TH': 'Asia',
  'TJ': 'Asia',
  'TL': 'Asia',
  'TM': 'Asia',
  'TN': 'Africa',
  'TR': 'Asia',
  'TT': 'North America',
  'TZ': 'Africa',
  'UA': 'Europe',
  'UG': 'Africa',
  'US': 'North America',
  'UY': 'South America',
  'UZ': 'Asia',
  'VE': 'South America',
  'VN': 'Asia',
  'VU': 'Oceania',
  'YE': 'Asia',
  'ZA': 'Africa',
  'ZM': 'Africa',
  'ZW': 'Africa',
};

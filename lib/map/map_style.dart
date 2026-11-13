import 'dart:ui';

/// The maps' colours: the globe (profile, onboarding) and the location
/// picker.
abstract final class MapColors {
  /// Land fill of every country.
  static const landColor = Color(0xFF0B0D0F);

  /// Faint internal province divisions.
  static const provinceBorderColor = Color(0x40FFFFFF);

  /// Bright international borders.
  static const countryBorderColor = Color(0xFFFFFFFF);

  /// Ocean / background behind the land.
  static const oceanColor = Color(0xFF2B2F33);
}

/// Shades a region by how many posts it holds, matching the referral badge
/// tier colours: 0-20 light blue, 21-40 dark blue, 41-60 purple, 61-80 pink,
/// 80+ red.
Color travelMapColorForCount(int count) {
  if (count <= 20) return const Color(0xFF5BB8E8); // light blue
  if (count <= 40) return const Color(0xFF1E7FE0); // dark blue
  if (count <= 60) return const Color(0xFFA020C7); // purple
  if (count <= 80) return const Color(0xFFED2A93); // pink
  return const Color(0xFFE01B24); // red (80+)
}

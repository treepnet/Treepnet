import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/map/geo_regions.dart';

/// Where the post was put, over its globe (the new feed: its bottom left
/// corner): the globe's white pin and the place's country and city (the
/// region), in the app's language — "Uzbekistan, Tashkent" — white,
/// shadowed to read on land and sea. While the map data isn't in (or out
/// at sea), the post's region as saved. Nothing when there is no place.
class FeedPostPlace extends StatelessWidget {
  const FeedPostPlace({required this.block, required this.map, super.key});

  final PostBlock block;

  /// The author's travel map, as the globe shows it (the post's pin is in
  /// it).
  final TravelMap? map;

  String _line(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final pin = map?.pinOf(block.id);
    final geo = GeoRegions.instance;
    final region = pin != null && geo.isLoaded
        ? geo.regionAt(pin.lng, pin.lat)
        : null;
    // No region to read (the map data not in yet, or out at sea): the post's
    // region as it was saved.
    if (region == null) return block.location?.trim() ?? '';
    final country = region.localizedCountryName(lang).trim();
    final city = region.localizedDisplayName(lang).trim();
    return [
      if (country.isNotEmpty) country,
      if (city.isNotEmpty && city.toLowerCase() != country.toLowerCase()) city,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final line = _line(context);
    if (line.isEmpty) return const SizedBox.shrink();
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on,
          color: AppColors.white,
          size: 20,
          shadows: shadow,
        ),
        const Gap.h(AppSpacing.xs),
        Expanded(
          child: Text(
            line,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.bodyLarge?.copyWith(
              fontWeight: AppFontWeight.semiBold,
              color: AppColors.white,
              shadows: shadow,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/map/geo_regions.dart';

/// Where the post was put (the new feed, a prototype): the globe's white pin
/// and the place's country and city (the region), in the app's language,
/// in the card's buttons' place under the globe: "Uzbekistan, Tashkent".
/// Before the map data is in, the post's region as saved. Nothing when
/// there is no place.
class FeedPostPlace extends StatefulWidget {
  const FeedPostPlace({required this.block, this.onGlobe = false, super.key});

  final PostBlock block;

  /// Over the globe (the new feed: its bottom left corner): white, shadowed
  /// to read on land and sea.
  final bool onGlobe;

  @override
  State<FeedPostPlace> createState() => _FeedPostPlaceState();
}

class _FeedPostPlaceState extends State<FeedPostPlace> {
  // The globe asks for the same map at the same moment: one request, then
  // the cache (DatabaseClient.travelMapOf).
  late Future<TravelMap?> _map = _fetch();

  Future<TravelMap?> _fetch() => context.read<PostsRepository>().travelMapOf(
    userId: widget.block.author.id,
  );

  @override
  void initState() {
    super.initState();
    final geo = GeoRegions.instance;
    if (!geo.isLoaded) {
      // The country and the city come from the map data.
      unawaited(
        geo.load().then((_) {
          if (mounted) setState(() {});
        }, onError: (Object _) {}),
      );
    }
  }

  @override
  void didUpdateWidget(covariant FeedPostPlace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.author.id != widget.block.author.id) _map = _fetch();
  }

  String _line(TravelMap? map) {
    final lang = Localizations.localeOf(context).languageCode;
    final pin = map?.pinOf(widget.block.id);
    final geo = GeoRegions.instance;
    final region = pin != null && geo.isLoaded
        ? geo.regionAt(pin.lng, pin.lat)
        : null;
    // No region to read (the map data not in yet, or out at sea): the post's
    // region as it was saved.
    if (region == null) return widget.block.location?.trim() ?? '';
    final country = region.localizedCountryName(lang).trim();
    final city = region.localizedDisplayName(lang).trim();
    return [
      if (country.isNotEmpty) country,
      if (city.isNotEmpty && city.toLowerCase() != country.toLowerCase()) city,
    ].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TravelMap?>(
      future: _map,
      builder: (context, snapshot) {
        final line = _line(snapshot.data);
        if (line.isEmpty) return const SizedBox.shrink();
        const shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on,
              color: AppColors.white,
              size: 20,
              shadows: widget.onGlobe ? shadow : null,
            ),
            const Gap.h(AppSpacing.xs),
            Expanded(
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bodyLarge?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                  color: widget.onGlobe ? AppColors.white : null,
                  shadows: widget.onGlobe ? shadow : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

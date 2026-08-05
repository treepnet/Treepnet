import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/map/map.dart';

/// Profile tab showing the user's "travel map": every ISO 3166-2 region they
/// have posted from is highlighted on an interactive world map. Nothing else.
///
/// The map fills the tab. It used to be pinned to a fixed height at the top,
/// which left dead space underneath once the profile header collapsed and the
/// tab grew.
class UserProfileTravelMap extends StatelessWidget {
  const UserProfileTravelMap({required this.userId, super.key});

  /// Breathing room so the map doesn't touch the panel edges.
  static const _inset = 5.0;

  final String userId;

  /// Captured once; see [VisitedRegionsPage] — a per-build future resets the map.
  static final Future<void> _geoReady = GeoRegions.instance.load();

  @override
  Widget build(BuildContext context) {
    final postsRepository = context.read<PostsRepository>();
    // Story points are reverse-geocoded below, which needs the region polygons
    // in memory. `load()` caches, so this resolves instantly after the first
    // call — but without it the first build would silently find no regions.
    return FutureBuilder<void>(
      future: _geoReady,
      builder: (context, _) => _buildMap(context, postsRepository),
    );
  }

  Widget _buildMap(BuildContext context, PostsRepository postsRepository) {
    return StreamBuilder<Map<String, int>>(
      stream: postsRepository.visitedRegionCountsOf(userId: userId),
      builder: (context, regionSnap) {
        final visited = regionSnap.data ?? const <String, int>{};
        return StreamBuilder<List<({double lat, double lng, String? name})>>(
          stream: postsRepository.visitedPointsOf(userId: userId),
          builder: (context, pointSnap) {
            final postPoints =
                pointSnap.data ??
                const <({double lat, double lng, String? name})>[];
            // Story locations also drop a pin — and they persist here even
            // after the 24h story has expired.
            return StreamBuilder<List<({double lat, double lng, String? name})>>(
              stream: postsRepository.storyPointsOf(userId: userId),
              builder: (context, storySnap) {
                final storyPoints = storySnap.data ?? const [];
                final points = <({double lat, double lng, String? name})>[
                  ...postPoints,
                  ...storyPoints,
                ];
                return Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: TravelMap(
                    visitedCounts: _withStoryRegions(visited, storyPoints),
                    points: points,
                    // Fills whatever the tab gives it, header collapsed or not.
                    // Safe to resize because the camera is only *centre*
                    // constrained — see `TravelMap._contentBounds`.
                    height: double.infinity,
                    onTargetTap: (target) => LocationPostsPage.push(
                      context,
                      userId: userId,
                      regionIso: target.region.iso,
                      regionName: target.region.name,
                      // The name the author gave this spot — the heading of the
                      // page, since "Magic city bogi" is what they remember,
                      // not the province it happens to fall in.
                      placeName: target.point?.name,
                      countryName: target.region.countryName,
                      scope: target.point == null
                          ? LocationPostsScope.region
                          : LocationPostsScope.point,
                      lat: target.point?.lat,
                      lng: target.point?.lng,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Region shading comes from `posts.location_region`, but stories only store a
/// lat/lng — no region code. So a story pinned to a place used to drop a pin
/// without ever colouring the region it sits in. Reverse-geocode each story
/// point here and fold it into the counts, so posting a story lights up its
/// region just like a post does.
Map<String, int> _withStoryRegions(
  Map<String, int> postCounts,
  List<({double lat, double lng, String? name})> storyPoints,
) {
  if (storyPoints.isEmpty) return postCounts;
  final geo = GeoRegions.instance;
  final merged = Map<String, int>.of(postCounts);
  for (final point in storyPoints) {
    final region = geo.regionAt(point.lng, point.lat);
    if (region == null) continue;
    merged.update(region.iso, (count) => count + 1, ifAbsent: () => 1);
  }
  return merged;
}

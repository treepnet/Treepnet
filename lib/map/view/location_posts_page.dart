import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:treepnet/user_profile/widgets/user_profile_create_post.dart';

/// Where [LocationPostsPage] was opened from: a single pin, or a whole region.
enum LocationPostsScope {
  /// Posts within a short radius of one point — what tapping a pin gives.
  point,

  /// Every post in the region.
  region,
}

/// {@template location_posts_page}
/// The place behind one spot on the travel map, in two tabs.
///
/// `Posts` answers "what did I post from here?". `Stories` is a hand-built
/// collection: stories are never filed here automatically, the author pins them
/// out of their archive — which is what keeps a place worth revisiting after
/// the 24h window has closed on everything.
/// {@endtemplate}
class LocationPostsPage extends StatelessWidget {
  /// {@macro location_posts_page}
  const LocationPostsPage({
    required this.userId,
    required this.regionIso,
    required this.regionName,
    required this.scope,
    this.placeName,
    this.countryName,
    this.lat,
    this.lng,
    super.key,
  });

  final String userId;
  final String regionIso;
  final String regionName;
  final String? countryName;
  final LocationPostsScope scope;

  /// The name the author typed when pinning this spot ("Magic city bogi").
  /// Null for a whole region, which nobody named.
  final String? placeName;

  /// The tapped point. Required when [scope] is [LocationPostsScope.point].
  final double? lat;
  final double? lng;

  /// Opens this page.
  ///
  /// Everything travels in the URL rather than in `extra`, which GoRouter drops
  /// whenever it rebuilds the route — a rebuild would otherwise leave the page
  /// with no idea which place it is showing.
  static void push(
    BuildContext context, {
    required String userId,
    required String regionIso,
    required String regionName,
    required LocationPostsScope scope,
    String? placeName,
    String? countryName,
    double? lat,
    double? lng,
  }) {
    context.pushNamed(
      AppRoutes.locationPosts.name,
      queryParameters: {
        'userId': userId,
        'iso': regionIso,
        'name': regionName,
        'scope': scope.name,
        if (placeName != null && placeName.isNotEmpty) 'place': placeName,
        if (countryName != null) 'country': countryName,
        if (lat != null) 'lat': '$lat',
        if (lng != null) 'lng': '$lng',
      },
    );
  }

  /// Rebuilds the page from the URL — see [push].
  factory LocationPostsPage.fromQuery(Map<String, String> query) {
    final lat = double.tryParse(query['lat'] ?? '');
    final lng = double.tryParse(query['lng'] ?? '');
    // A point view without coordinates cannot query anything; fall back to the
    // region rather than crashing on a bad URL.
    final wanted = LocationPostsScope.values
        .where((s) => s.name == query['scope'])
        .firstOrNull;
    final scope =
        (wanted == LocationPostsScope.point && lat != null && lng != null)
        ? LocationPostsScope.point
        : LocationPostsScope.region;
    return LocationPostsPage(
      userId: query['userId'] ?? '',
      regionIso: query['iso'] ?? '',
      regionName: query['name'] ?? '',
      placeName: query['place'],
      countryName: query['country'],
      scope: scope,
      lat: lat,
      lng: lng,
    );
  }

  /// The heading: the name the author gave this spot, falling back to the
  /// region when there is none to show (a region tap, or an older pin saved
  /// before names were asked for).
  String get _title => (placeName != null && placeName!.trim().isNotEmpty)
      ? placeName!.trim()
      : regionName;

  Stream<List<Post>> _posts(PostsRepository repository) => switch (scope) {
    LocationPostsScope.point => repository.postsAtPoint(
      userId: userId,
      lat: lat!,
      lng: lng!,
    ),
    LocationPostsScope.region => repository.postsInRegion(
      userId: userId,
      iso: regionIso,
    ),
  };

  @override
  Widget build(BuildContext context) {
    // Only the owner of the map may add to it.
    final isOwner = context.select((AppBloc bloc) => bloc.state.user.id) ==
        userId;

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) => TreepNetAmbientBackground(
          child: AppScaffold(
            backgroundColor: AppColors.transparent,
            appBar: AppBar(
              backgroundColor: AppColors.transparent,
              surfaceTintColor: AppColors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: context.colorScheme.onSurface,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              centerTitle: true,
              // Just the name the author gave the place. The region used to sit
              // under it, but it repeats what the map already showed and pushed
              // the name off-centre.
              title: Text(
                _title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.titleMedium?.copyWith(
                  // Exactly the feed's Posts/Stories tabs — 24px semiBold — so
                  // headings across the app are one size, not merely one
                  // weight. See _FeedTab in feed_top_bar.dart.
                  fontSize: 24,
                  fontWeight: AppFontWeight.semiBold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              actions: [
                if (isOwner)
                  // Add + only on the Posts tab; it disappears on Stories.
                  AnimatedBuilder(
                    animation: DefaultTabController.of(context),
                    builder: (context, _) {
                      if (DefaultTabController.of(context).index != 0) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.md),
                        child: Tappable.faded(
                          onTap: () => _add(context),
                          child: Text(
                            context.l10n.locationAddText,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: AppFontWeight.semiBold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
              bottom: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 1,
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: context.l10n.locationTabPosts),
                  Tab(text: context.l10n.locationTabStories),
                ],
              ),
            ),
            body: SafeArea(
              top: false,
              child: TabBarView(
                children: [
                  _PostsTab(
                    // Built once, inside the tab's State — see _PostsTabState.
                    openStream: () => _posts(context.read<PostsRepository>()),
                    userId: userId,
                    regionIso: regionIso,
                    lat: lat,
                    lng: lng,
                    onSeeWholeRegion: scope == LocationPostsScope.point
                        ? () => LocationPostsPage.push(
                            context,
                            userId: userId,
                            regionIso: regionIso,
                            regionName: regionName,
                            countryName: countryName,
                            scope: LocationPostsScope.region,
                          )
                        : null,
                  ),
                  _StoriesTab(
                    userId: userId,
                    regionIso: regionIso,
                    lat: lat,
                    lng: lng,
                    canEdit: isOwner,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `Add +` does whatever the visible tab is about: a new post at this place,
  /// or a story lifted out of the archive.
  Future<void> _add(BuildContext context) {
    final onStories = DefaultTabController.of(context).index == 1;
    return onStories ? _pinStoryHere(context) : _addPostHere(context);
  }

  /// Starts the normal create-post flow with this place already filled in, so
  /// the user isn't asked to find on a map the spot they just tapped.
  Future<void> _addPostHere(BuildContext context) async {
    final region = GeoRegions.instance.regionByIso(regionIso);
    if (region == null) return;
    final seed = LocationSeed(
      region: region,
      // A region tap has no pin of its own; its centroid is the honest answer.
      lat: lat ?? region.centroidLngLat.dy,
      lng: lng ?? region.centroidLngLat.dx,
      // This place already has a name (or falls back to the region) — pass it so
      // the publish screen doesn't demand the location be picked again.
      name: _title,
    );
    await createPostAt(context, seed);
  }

  Future<void> _pinStoryHere(BuildContext context) => showArchivePicker(
    context,
    userId: userId,
    regionIso: regionIso,
    lat: lat,
    lng: lng,
  );
}

/// Posts at this place, in the same grid the profile and search use.
class _PostsTab extends StatefulWidget {
  const _PostsTab({
    required this.openStream,
    required this.onSeeWholeRegion,
    required this.userId,
    required this.regionIso,
    required this.lat,
    required this.lng,
  });

  /// Opens the feed. Called exactly once — PowerSync's `watch` is
  /// single-subscription, so a stream rebuilt in `build` blows up with
  /// "Stream has already been listened to" the moment anything writes.
  final Stream<List<Post>> Function() openStream;

  /// From a pin you can widen out; from a region there is nowhere wider to go.
  final VoidCallback? onSeeWholeRegion;

  /// Who/where this place is — needed to tell, after a delete empties the grid,
  /// whether the place still holds pinned stories (if not, we leave the page).
  final String userId;
  final String regionIso;
  final double? lat;
  final double? lng;

  @override
  State<_PostsTab> createState() => _PostsTabState();
}

class _PostsTabState extends State<_PostsTab> {
  late final Stream<List<Post>> _posts = widget.openStream();

  /// Have we seen posts here at least once? A place that opens empty was always
  /// empty — only a place that *emptied* (a delete) should be able to pop.
  bool _hadPosts = false;

  /// Guards the async empty-check so a burst of rebuilds can't fire N pops.
  bool _leaving = false;

  /// After a delete drops the grid to zero, leave the page — but only if the
  /// place is now truly empty, i.e. it has no pinned stories either. A
  /// story-only place must stay open so it can still be reached from the map.
  Future<void> _leaveIfTrulyEmpty() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final stories = await context
          .read<StoriesRepository>()
          .locationStoriesOf(
            userId: widget.userId,
            regionIso: widget.regionIso,
            lat: widget.lat,
            lng: widget.lng,
          )
          .first;
      if (!mounted) return;
      if (stories.isEmpty) {
        Navigator.of(context).maybePop();
      } else {
        // Stays open on the Stories tab; allow a future delete to re-check.
        _leaving = false;
      }
    } catch (_) {
      _leaving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: _posts,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (items.isNotEmpty) {
          _hadPosts = true;
        } else if (_hadPosts && !_leaving) {
          // Went from some posts to none — a delete. Check for pinned stories
          // after this frame, then leave if there is nothing left here.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _leaveIfTrulyEmpty(),
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    context.l10n.locationPostsCount(items.length),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onSeeWholeRegion != null)
                    Tappable.faded(
                      onTap: widget.onSeeWholeRegion,
                      child: Text(
                        context.l10n.locationWholeRegionText,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _LocationEmpty(
                      icon: Icons.image_not_supported_outlined,
                      text: context.l10n.noPostsHereText,
                    )
                  : _PostsGrid(posts: items),
            ),
          ],
        );
      },
    );
  }
}

/// Empty state for a tab in the location page — a large white icon over a
/// large white label. We stay put rather than leaving the page: the place may
/// still hold pinned stories on the Stories tab.
class _LocationEmpty extends StatelessWidget {
  const _LocationEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.white, size: 64),
        const Gap.v(AppSpacing.md),
        Text(
          text,
          style: context.titleMedium?.copyWith(
            color: AppColors.white,
            fontWeight: AppFontWeight.semiBold,
          ),
        ),
      ],
    ),
  );
}

/// The Trends/profile tile: 3 columns, hairline gaps, square corners, and a tap
/// that opens the scrollable feed rather than a single post.
class _PostsGrid extends StatelessWidget {
  const _PostsGrid({required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 133 / 170,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        // `Post` has no thumbnail helpers; the small block it converts to does.
        final block = posts[index].toPostSmallBlock;
        if (block.firstMediaUrl == null) return const SizedBox.shrink();
        return PostPopup(
          key: ValueKey(block.id),
          block: block,
          index: index,
          showComments: false,
          // Stay inside this place: without it a tap opened the newest posts
          // from everywhere and scrolled straight out of the location.
          feedPosts: posts,
          builder: (_) => PostSmall(
            pinned: false,
            isReel: block.isReel,
            multiMedia: block.media.length > 1,
            mediaUrl: block.firstMediaUrl!,
            imageThumbnailBuilder: (_, _) => PostSmallImage(post: block),
          ),
        );
      },
    );
  }
}

/// Stories the author pinned to this place, newest pin first.
class _StoriesTab extends StatefulWidget {
  const _StoriesTab({
    required this.userId,
    required this.regionIso,
    required this.lat,
    required this.lng,
    required this.canEdit,
  });

  final String userId;
  final String regionIso;
  final double? lat;
  final double? lng;
  final bool canEdit;

  @override
  State<_StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<_StoriesTab> {
  /// Opened once: PowerSync's `watch` allows a single listener, and rebuilding
  /// it inside `build` threw as soon as pinning a story wrote to the table.
  late final Stream<List<Story>> _stories = context
      .read<StoriesRepository>()
      .locationStoriesOf(
        userId: widget.userId,
        regionIso: widget.regionIso,
        lat: widget.lat,
        lng: widget.lng,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Story>>(
      stream: _stories,
      builder: (context, snapshot) {
        final stories = snapshot.data;
        if (stories == null) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (stories.isEmpty) {
          return _LocationEmpty(
            // Same icon as the Posts tab's empty state, so both tabs read alike.
            icon: Icons.image_not_supported_outlined,
            text: context.l10n.noStoriesHereText,
          );
        }
        return GridView.builder(
          padding: EdgeInsets.zero,
          // The Trends/profile tile, so a place's stories and its posts read as
          // one grid instead of two different ones.
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 133 / 170,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            return Tappable.scaled(
              // Replays from the tapped story onwards, like the viewer.
              onTap: () => context.pushNamed(
                AppRoutes.stories.name,
                pathParameters: {'user_id': story.author.id},
                extra: StoriesProps(
                  stories: stories.sublist(index),
                  author: story.author,
                ),
              ),
              onLongPress: !widget.canEdit
                  ? null
                  : () => _confirmUnpin(context, story),
              child: _StoryTile(story: story),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmUnpin(BuildContext context, Story story) {
    final repository = context.read<StoriesRepository>();
    return context.confirmAction(
      title: context.l10n.locationUnpinStoryText,
      content: context.l10n.locationStoryPinnedText,
      noText: context.l10n.cancelText,
      yesText: context.l10n.locationUnpinStoryText,
      yesTextStyle: const TextStyle(color: AppColors.red),
      fn: () => repository.unpinStoryFromLocation(
        userId: widget.userId,
        storyId: story.id,
        regionIso: widget.regionIso,
        lat: widget.lat,
        lng: widget.lng,
      ),
    );
  }
}

/// A story cover with its date, shared by the pinned grid and the picker.
class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.story,
    this.selected = false,
    this.showDate = false,
  });

  final Story story;
  final bool selected;

  /// Only the archive dates its covers — there the day is how you find the one
  /// you want. On a place's grid it is noise over the picture.
  final bool showDate;

  static String _shortDate(DateTime at) =>
      '${at.day}.${at.month.toString().padLeft(2, '0')}.${at.year}';

  @override
  Widget build(BuildContext context) {
    // Square corners: a story tile is the same object as a post tile, and a
    // rounded one broke the run of the grid.
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: story.contentUrl,
            fit: BoxFit.cover,
            memCacheWidth: 480,
            placeholder: (_, _) => const ColoredBox(color: AppColors.dark),
            errorWidget: (_, _, _) => const ColoredBox(color: AppColors.dark),
          ),
          if (selected)
            const ColoredBox(color: Color(0x883897F0))
          else
            const SizedBox.shrink(),
          if (showDate)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Text(
                  _shortDate(story.createdAt),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 11,
                    shadows: [Shadow(color: AppColors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lets the author pick stories out of their archive and pin them here.
///
/// The archive is the only source: a story only reaches it after its 24h in the
/// feed, which is exactly when it would otherwise be lost.
Future<void> showArchivePicker(
  BuildContext context, {
  required String userId,
  required String regionIso,
  double? lat,
  double? lng,
}) {
  final repository = context.read<StoriesRepository>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => FractionallySizedBox(
      heightFactor: 0.85,
      child: _ArchivePicker(
        repository: repository,
        userId: userId,
        regionIso: regionIso,
        lat: lat,
        lng: lng,
      ),
    ),
  );
}

class _ArchivePicker extends StatefulWidget {
  const _ArchivePicker({
    required this.repository,
    required this.userId,
    required this.regionIso,
    required this.lat,
    required this.lng,
  });

  final StoriesRepository repository;
  final String userId;
  final String regionIso;
  final double? lat;
  final double? lng;

  @override
  State<_ArchivePicker> createState() => _ArchivePickerState();
}

class _ArchivePickerState extends State<_ArchivePicker> {
  StoriesRepository get repository => widget.repository;

  /// Both opened once. Pinning writes to `location_stories`, which makes every
  /// watch re-emit and this widget rebuild — recreating the streams there would
  /// re-listen to a single-subscription stream and throw.
  late final Stream<List<Story>> _archive = repository.archivedStoriesOf(
    userId: widget.userId,
  );
  late final Stream<List<Story>> _pinned = repository.locationStoriesOf(
    userId: widget.userId,
    regionIso: widget.regionIso,
    lat: widget.lat,
    lng: widget.lng,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            context.l10n.locationPickFromArchiveTitle,
            style: context.titleMedium?.copyWith(
              color: AppColors.white,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        Expanded(
          // Two streams: everything in the archive, and what is already pinned
          // here — so an already-pinned story reads as done instead of
          // silently doing nothing when tapped.
          child: StreamBuilder<List<Story>>(
            stream: _archive,
            builder: (context, archiveSnap) {
              final archive = archiveSnap.data;
              if (archive == null) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }
              if (archive.isEmpty) {
                return Center(
                  child: Text(
                    context.l10n.locationArchiveEmptyText,
                    style: context.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }
              return StreamBuilder<List<Story>>(
                stream: _pinned,
                builder: (context, pinnedSnap) {
                  final pinned = {
                    for (final story in pinnedSnap.data ?? const <Story>[])
                      story.id,
                  };
                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xlg),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 133 / 170,
                        ),
                    itemCount: archive.length,
                    itemBuilder: (context, index) {
                      final story = archive[index];
                      final isPinned = pinned.contains(story.id);
                      return Tappable.scaled(
                        onTap: () async {
                          if (isPinned) {
                            await repository.unpinStoryFromLocation(
                              userId: widget.userId,
                              storyId: story.id,
                              regionIso: widget.regionIso,
                              lat: widget.lat,
                              lng: widget.lng,
                            );
                          } else {
                            await repository.pinStoryToLocation(
                              userId: widget.userId,
                              storyId: story.id,
                              regionIso: widget.regionIso,
                              lat: widget.lat,
                              lng: widget.lng,
                            );
                          }
                        },
                        child: _StoryTile(
                          story: story,
                          selected: isPinned,
                          showDate: true,
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

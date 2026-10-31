import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/search/view/search_page.dart';
import 'package:treepnet/timeline/timeline.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' hide VideoPlayer;
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:powersync_repository/powersync_repository.dart'
    show PowerSyncRepository;
import 'package:shared/shared.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sliver_tools/sliver_tools.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          TimelineBloc(postsRepository: context.read<PostsRepository>())
            ..add(const TimelinePageRequested()),
      child: const TimelineView(),
    );
  }
}

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView>
    with SingleTickerProviderStateMixin {
  late final Animation<double> _animation = CurvedAnimation(
    curve: Curves.easeOutQuad,
    parent: _controller,
  );
  late final AnimationController _controller = AnimationController(vsync: this);
  final _isNextPageLoading = ValueNotifier(false);
  StreamSubscription<void>? _syncSub;
  DateTime? _lastSyncedAt;

  /// Whether this device has synced at all: an empty grid before that is
  /// still loading, after it there are really no posts to show.
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    final db = context.read<PowerSyncRepository>().db();
    _hasSynced = db.currentStatus.hasSynced ?? false;
    _lastSyncedAt = db.currentStatus.lastSyncedAt;
    // A first page read before this account's rows arrived came back empty
    // (or failed) and was never asked again: the grid loaded forever, and
    // its "no more pages" stopped paging too. Once a sync lands, try again.
    _syncSub = db.statusStream.listen((status) {
      final syncedAt = status.lastSyncedAt;
      if (syncedAt == null || syncedAt == _lastSyncedAt || !mounted) return;
      _lastSyncedAt = syncedAt;
      if (!_hasSynced) setState(() => _hasSynced = true);
      final bloc = context.read<TimelineBloc>();
      if (bloc.state.timeline.blocks.isEmpty || bloc.state.status.isFailure) {
        bloc.add(const TimelineRefreshRequested());
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _isNextPageLoading.dispose();
    super.dispose();
  }

  /// Waits (at most 15s) for the bloc to settle, so a spinner stays up until
  /// the answer is in rather than closing right away.
  Future<void> _settled(bool Function(TimelineState state) done) async {
    final bloc = context.read<TimelineBloc>();
    await bloc.stream
        .firstWhere(done)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select(
      (TimelineBloc bloc) => bloc.state.timeline.hasMore,
    );

    return AppScaffold(
      releaseFocus: true,
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          context.read<TimelineBloc>().add(const TimelineRefreshRequested());
          await _settled((state) => !state.status.isLoading);
        },
        child: InViewNotifierCustomScrollView(
          onListEndReached: () async {
            if (!hasMore) return;
            Future<void> onEndReached() async {
              final bloc = context.read<TimelineBloc>();
              final page = bloc.state.timeline.page;
              bloc.add(const TimelinePageRequested());
              await _settled(
                (state) =>
                    state.timeline.page != page || state.status.isFailure,
              );
            }

            if (_isNextPageLoading.value) return;

            _controller
              ..duration = Duration.zero
              // ignore: unawaited_futures
              ..forward();

            _isNextPageLoading.value = true;

            await onEndReached().whenComplete(() {
              if (mounted) {
                _controller
                  ..duration = const Duration(milliseconds: 300)
                  ..reverse();

                _isNextPageLoading.value = false;
              }
            });
          },
          initialInViewIds: const ['2', '5'],
          isInViewPortCondition: (deltaTop, deltaBottom, vpHeight) =>
              deltaTop < (0.5 * vpHeight) + 220.0 &&
              deltaBottom > (0.5 * vpHeight) - 220.0,
          slivers: [
            const SliverAppBar(
              title: SearchInputField(active: true, readOnly: true),
              floating: true,
              toolbarHeight: 64,
            ),
            BlocBuilder<TimelineBloc, TimelineState>(
              // A change of status rebuilds too: a failure (or an empty first
              // page) used to leave the loading shimmer up for good.
              buildWhen: (previous, current) {
                return previous.status != current.status ||
                    !const ListEquality<InstaBlock>().equals(
                      previous.timeline.blocks,
                      current.timeline.blocks,
                    );
              },
              builder: (context, state) {
                final blocks = state.timeline.blocks;
                // Posts on screen stay on screen, whatever the status.
                if (blocks.isEmpty && state.status.isFailure) {
                  return const TimelineError();
                }
                return SliverAnimatedSwitcher(
                  duration: 150.ms,
                  child: blocks.isNotEmpty
                      ? TimelineGridView(blocks: blocks.cast<PostBlock>())
                      : _hasSynced && state.status.isPopulated
                      ? const TimelineEmpty()
                      : const TimelineLoading(),
                );
              },
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                top:
                    16 +
                    (context.isMobile ? MediaQuery.paddingOf(context).top : 0),
              ),
              sliver: SliverToBoxAdapter(
                child: SizeTransition(
                  axisAlignment: 1,
                  sizeFactor: _animation,
                  child: Center(
                    child: Container(
                      alignment: Alignment.center,
                      height: 38,
                      width: 38,
                      child: const SizedBox(
                        height: 26,
                        width: 26,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineGridView extends StatelessWidget {
  const TimelineGridView({required this.blocks, super.key});

  final List<PostBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      // Uniform 3-column grid of portrait tiles (Figma "Trends" — each tile is
      // ~133x170, ratio ≈ 0.78).
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        childAspectRatio: 133 / 170,
      ),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        final multiMedia = block.media.length > 1;

        return PostPopup(
          key: ValueKey(block.id),
          block: block,
          index: index,
          showComments: false,
          builder: (_) => PostSmall(
            pinned: false,
            isReel: block.isReel,
            multiMedia: multiMedia,
            mediaUrl: block.firstMediaUrl ?? '',
            imageThumbnailBuilder: (_, url) => block.isReel
                ? VideoPlayerInViewNotifierWidget(
                    type: VideoPlayerType.timeline,
                    id: '$index',
                    checkIsInView: true,
                    builder: (context, shouldPlay, child) {
                      return InlineVideo(
                        videoSettings: VideoSettings.build(
                          videoUrl: block.firstMedia?.url ?? '',
                          shouldPlay: shouldPlay,
                          withSound: false,
                          shouldExpand: true,
                          blurHash: block.firstMedia?.blurHash,
                          withSoundButton: false,
                          withPlayerController: false,
                          videoPlayerOptions: VideoPlayerOptions(
                            mixWithOthers: true,
                          ),
                          initDelay: 250,
                        ),
                      );
                    },
                  )
                : TimelinePostImage(post: block),
          ),
        );
      },
    );
  }
}

class TimelinePostImage extends StatelessWidget {
  const TimelinePostImage({required this.post, super.key});

  final PostBlock post;

  @override
  Widget build(BuildContext context) {
    return BlurHashImageThumbnail(
      id: post.id,
      // A third of a phone screen, so a fixed cap is plenty — and it keeps
      // every tile the same shape regardless of screen density.
      decodeWidth: 480,
      url: post.firstMediaThumbUrl ?? '',
      blurHash: post.firstMedia?.blurHash,
    );
  }
}

class TimelineLoading extends StatelessWidget {
  const TimelineLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Shimmer.fromColors(
        baseColor: context.customReversedAdaptiveColor(
            dark: AppColors.emphasizeDarkGrey, light: AppColors.brightGrey),
        highlightColor: context.customReversedAdaptiveColor(
            dark: AppColors.dark, light: AppColors.grey),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 133 / 170,
          ),
          itemCount: 20,
          itemBuilder: (context, index) =>
              const ColoredBox(color: AppColors.dark),
        ),
      ),
    );
  }
}

/// No posts to show, after a sync (before one the grid is still loading).
class TimelineEmpty extends StatelessWidget {
  const TimelineEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Text(
          context.l10n.noPostsHereText,
          style: context.titleMedium,
        ),
      ),
    );
  }
}

class TimelineError extends StatelessWidget {
  const TimelineError({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            context.l10n.somethingWentWrongText,
            style: context.headlineSmall,
          ),
          gapH8,
          FittedBox(
            child: Tappable.faded(
              onTap: () => context.read<TimelineBloc>().add(
                const TimelinePageRequested(),
              ),
              throttle: true,
              throttleDuration: 880.ms,
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderOutline),
                ),
                child: Align(
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.refresh),
                      gapW12,
                      Text(context.l10n.refreshText, style: context.labelLarge),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// `show`: the package also exports sqlite3's `Row`, which collides with the
// widget of the same name.
import 'package:powersync_repository/powersync_repository.dart'
    show PowerSyncRepository;
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/feed/widgets/post_upload_progress.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:shared/shared.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key, this.initialPage = 1});

  final int initialPage;

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> with RouteAware {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage);
    context.read<UserProfileBloc>().add(
      const UserProfileFetchFollowingsRequested(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StoriesBloc(
        storiesRepository: context.read<StoriesRepository>(),
        userRepository: context.read<UserRepository>(),
      )..add(const StoriesFetchUserFollowingsStories()),
      child: const FeedView(),
    );
  }
}

/// {@template feed_view}
/// The main FeedView widget that builds the UI for the feed screen.
/// {@endtemplate}
class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  late ScrollController _nestedScrollController;

  /// 0 = Posts, 1 = Stories. The design splits the feed into two tabs instead
  /// of stacking a stories row above the posts.
  int _tab = 0;

  /// Drives the swipe between the two tabs. A horizontal drag here used to
  /// reach the camera / chats through the home PageView; those now open from
  /// the bottom bar instead.
  final _tabController = PageController();

  /// Refreshes the feed each time PowerSync finishes a sync round.
  StreamSubscription<void>? _syncSub;

  @override
  void initState() {
    super.initState();
    context.read<FeedBloc>().add(const FeedPageRequested(page: 0));
    unawaited(_refetchWhenFirstSyncLands());

    _nestedScrollController = ScrollController();
    FeedPageController().init(
      nestedScrollController: _nestedScrollController,
      context: context,
    );
  }

  /// The first fetch above runs on frame one, when PowerSync has usually not
  /// finished streaming this account's rows — the read comes back empty and,
  /// because it is a one-shot query rather than a `watch`, nothing ever asks
  /// again. That is why the feed sat blank until a manual pull-to-refresh.
  ///
  /// Watches the status stream rather than `waitForFirstSync`: the local
  /// database is not wiped between accounts, so after a fresh registration on a
  /// device that had synced before, `hasSynced` was already true and the wait
  /// returned instantly — long before the new account's own rows arrived.
  Future<void> _refetchWhenFirstSyncLands() async {
    final db = context.read<PowerSyncRepository>().db();
    DateTime? lastSeen = db.currentStatus.lastSyncedAt;

    _syncSub = db.statusStream.listen((status) {
      final syncedAt = status.lastSyncedAt;
      if (syncedAt == null || syncedAt == lastSeen) return;
      lastSeen = syncedAt;
      if (!mounted) return;
      context.read<FeedBloc>().add(const FeedRefreshRequested());
      context.read<StoriesBloc>().add(
        const StoriesFetchUserFollowingsStories(),
      );
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _nestedScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      releaseFocus: true,
      body: Column(
        children: [
          FeedTopBar(
            currentTab: _tab,
            onTabChanged: (tab) {
              if (tab == _tab) return;
              _tabController.animateToPage(
                tab,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
              );
            },
          ),
          Expanded(
            child: PageView(
              controller: _tabController,
              onPageChanged: (tab) => setState(() => _tab = tab),
              children: const [FeedBody(), StoriesGridView()],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedBody extends StatelessWidget {
  const FeedBody({super.key});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: () async {
        Future<void> refresh() async {
          context.read<FeedBloc>().add(const FeedRefreshRequested());
          context.read<StoriesBloc>().add(
            const StoriesFetchUserFollowingsStories(),
          );
        }

        await Future<void>.delayed(1.seconds);
        await refresh();
        FeedPageController().markAnimationAsUnseen();
      },
      child: InViewNotifierCustomScrollView(
        initialInViewIds: const ['0'],
        isInViewPortCondition: (deltaTop, deltaBottom, vpHeight) {
          return deltaTop < (0.5 * vpHeight) + 80.0 &&
              deltaBottom > (0.5 * vpHeight) - 80.0;
        },
        slivers: [
          // Stories moved to their own tab, so the posts list starts at the top.
          const _UploadProgressBanner(),
          BlocBuilder<FeedBloc, FeedState>(
            buildWhen: (previous, current) {
              // `isFailure` has to be in here. Without it a failed fetch never
              // rebuilt the widget, so the shimmer from the preceding `loading`
              // build stayed on screen with no way out but a manual refresh.
              return current.status.isFailure ||
                  (current.status.isLoading && current.feed.feedPage.page == 0) ||
                  (previous.status.isLoading && current.status.isPopulated) ||
                  (current.status.isPopulated &&
                      !const ListEquality<InstaBlock>().equals(
                        previous.feed.feedPage.blocks,
                        current.feed.feedPage.blocks,
                      ));
            },
            builder: (context, state) {
              final feedPage = state.feed.feedPage;

              // A failure with posts already on screen keeps the posts — only
              // an empty feed has nothing better to show than the error.
              if (state.status.isFailure && feedPage.blocks.isEmpty) {
                return SliverToBoxAdapter(
                  child: _FeedLoadFailure(
                    onRetry: () => context.read<FeedBloc>().add(
                      const FeedRefreshRequested(),
                    ),
                  ),
                );
              }

              final isLoading = state.status.isLoading;

              return SliverAnimatedSwitcher(
                duration: 150.ms,
                child: !isLoading
                    ? FeedPageListView(
                        blocks: feedPage.blocks,
                        hasMore: feedPage.hasMore,
                      )
                    : const SliverToBoxAdapter(
                        child: Column(
                          children: [
                            FeedLoadingBlock(),
                            Gap.v(AppSpacing.md),
                            FeedLoadingBlock(),
                          ],
                        ),
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Non-blocking "Posting… N%" banner shown under the stories row while a post
/// uploads. Driven by the [PostUploadProgress] singleton.
class _UploadProgressBanner extends StatelessWidget {
  const _UploadProgressBanner();

  @override
  Widget build(BuildContext context) {
    final progress = PostUploadProgress();
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, _) {
          if (!progress.active) return const SizedBox.shrink();
          final pct = (progress.progress * 100).clamp(0, 100).round();
          final done = pct >= 100;
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: progress.thumbnail != null
                      ? Image.memory(
                          progress.thumbnail!,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          width: 46,
                          height: 46,
                          color: AppColors.glassBackgroundLight,
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                ),
                const Gap.h(AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            done ? context.l10n.postedText : context.l10n.postingText,
                            style: context.bodyMedium?.copyWith(
                              fontWeight: AppFontWeight.semiBold,
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const Gap.v(AppSpacing.xs),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.progress,
                          minHeight: 4,
                          backgroundColor: AppColors.glassBackgroundLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown when the feed fails to load and there is nothing cached to fall back
/// on. Before this existed a failure just left the loading shimmer up forever.
class _FeedLoadFailure extends StatelessWidget {
  const _FeedLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxxlg,
      ),
      child: Column(
        children: [
          Text(
            context.l10n.somethingWentWrongText,
            textAlign: TextAlign.center,
            style: context.titleMedium,
          ),
          const Gap.v(AppSpacing.md),
          Tappable.scaled(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                border: Border.all(color: AppColors.borderOutline),
              ),
              child: Text(context.l10n.refreshText, style: context.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedPageListView extends StatefulWidget {
  const FeedPageListView({
    required this.blocks,
    required this.hasMore,
    super.key,
  });

  final List<InstaBlock> blocks;

  /// Whether the feed has more real posts to load. Passed down from the parent
  /// [BlocBuilder] because `context.select` cannot reach the [FeedBloc]
  /// provider from inside a [SliverList] itemBuilder.
  final bool hasMore;

  @override
  State<FeedPageListView> createState() => _FeedPageListViewState();
}

class _FeedPageListViewState extends State<FeedPageListView> {
  List<InstaBlock> get blocks => widget.blocks;

  final _listItemsMap = <String, int>{};

  @override
  void didUpdateWidget(covariant FeedPageListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blocks != widget.blocks) {
      _updateBlocks();
    }
  }

  void _updateBlocks() {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].toJson()['id'] == null) continue;
      _listItemsMap[blocks[i].toJson()['id'] as String] = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedPageController = FeedPageController();

    return SliverList.builder(
      // +1 for the trailing loader, kept as its own item so the last (oldest)
      // real post still renders instead of being replaced by the loader.
      itemCount: blocks.length + 1,
      findChildIndexCallback: (key) {
        final valueKey = key as ValueKey<String>;
        final val = _listItemsMap[valueKey.value];
        return val;
      },
      itemBuilder: (context, index) {
        if (index == blocks.length) {
          // Trailing loader. Hidden once real posts have loaded AND the feed is
          // exhausted, so it doesn't spin forever; an empty feed still waiting
          // for PowerSync keeps retrying instead of getting stuck empty.
          if (!widget.hasMore && blocks.isNotEmpty) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: EdgeInsets.only(top: blocks.isEmpty ? AppSpacing.md : 0),
            child: FeedLoaderItem(
              onPresented: () =>
                  context.read<FeedBloc>().add(const FeedPageRequested()),
            ),
          );
        }
        final block = blocks[index];
        return _buildBlock(
          context: context,
          index: index,
          feedLength: blocks.length,
          block: block,
          feedPageController: feedPageController,
        );
      },
    );
  }

  Widget _buildBlock({
    required BuildContext context,
    required int index,
    required int feedLength,
    required InstaBlock block,
    required FeedPageController feedPageController,
    // required bool hasMorePosts,
    // required bool isFailure,
  }) {
    if (block is DividerHorizontalBlock) {
      return DividerBlock(feedPageController: feedPageController);
    }
    if (block is SectionHeaderBlock) {
      return switch (block.sectionType) {
        SectionHeaderBlockType.suggested => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                context.l10n.suggestedForYouText,
                style: context.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const AppDivider(),
            if (index + 1 == feedLength)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: FeedLoaderItem(
                  onPresented: () => context.read<FeedBloc>().add(
                    const FeedRecommendedPostsPageRequested(),
                  ),
                ),
              ),
          ],
        ),
      };
    }
    if (block is PostBlock) {
      // return TestPageItem(post: block);
      return PostView(
        key: ValueKey(block.id),
        block: block,
        postIndex: index,
        withInViewNotifier: block.isReel,
      );
    }

    return Text('Unknown block type: ${block.type}');
  }
}

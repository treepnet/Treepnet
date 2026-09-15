import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';

/// A vertical, scrollable feed opened by tapping a tile in a grid. It starts on
/// the tapped post ([startPostId]) and keeps scrolling through the rest — so a
/// tap opens a feed, not a single post.
///
/// By default that rest is the newest posts across everyone. Pass [posts] to
/// scroll through a specific set instead: a place's grid has to stay inside
/// that place, otherwise tapping a photo of one spot walks you into everyone
/// else's.
class NewestPostsPage extends StatefulWidget {
  const NewestPostsPage({required this.startPostId, this.posts, super.key});

  final String startPostId;

  /// The exact feed to scroll, in order. Null means "the newest posts".
  final List<Post>? posts;

  @override
  State<NewestPostsPage> createState() => _NewestPostsPageState();
}

class _NewestPostsPageState extends State<NewestPostsPage> {
  late final ItemScrollController _itemScrollController;
  late final ItemPositionsListener _itemPositionsListener;
  late final ScrollOffsetController _scrollOffsetController;
  late final ScrollOffsetListener _scrollOffsetListener;

  /// The newest posts across everyone — the same source the explore grid
  /// pages through. (`postsOf()` is per-author and asserts on a null id,
  /// which is what made this screen throw.)
  late final Future<List<Post>> _future;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _itemScrollController = ItemScrollController();
    _itemPositionsListener = ItemPositionsListener.create();
    _scrollOffsetController = ScrollOffsetController();
    _scrollOffsetListener = ScrollOffsetListener.create();
    _future = widget.posts != null
        ? Future.value(widget.posts)
        : _loadNewestIncluding(
            context.read<PostsRepository>(),
            widget.startPostId,
          );
  }

  /// Loads the newest posts, paging until the tapped post ([startPostId]) is
  /// included. The explore/trend grid keeps paging in tiles well past a single
  /// page, so a lower tile's post could fall outside a fixed first-page fetch —
  /// and the id lookup below would then miss and fall back to index 0, opening
  /// the wrong (first) post. Paging by id (not position) also stays correct if
  /// a new post lands between the grid load and this one. Bounded so it can
  /// never spin. Matches the grid's `created_at DESC` order (same `getPage`).
  Future<List<Post>> _loadNewestIncluding(
    PostsRepository repo,
    String startPostId,
  ) async {
    final all = <Post>[];
    for (var offset = 0; offset < 1000; offset += _pageSize) {
      final batch = await repo.getPage(offset: offset, limit: _pageSize);
      all.addAll(batch);
      if (all.any((p) => p.id == startPostId)) break;
      if (batch.length < _pageSize) break; // reached the end
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        title: Text(context.l10n.postsText),
      ),
      body: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snapshot) {
          final posts = snapshot.data;
          if (posts == null) {
            return const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final blocks = <PostBlock>[
            for (final post in posts) post.toPostLargeBlock,
          ];
          var index = blocks.indexWhere((b) => b.id == widget.startPostId);
          if (index < 0) index = 0;

          return InViewNotifierCustomScrollView(
            initialInViewIds: [index.toString()],
            isInViewPortCondition: (deltaTop, deltaBottom, vpHeight) {
              return deltaTop < (0.5 * vpHeight) + 80.0 &&
                  deltaBottom > (0.5 * vpHeight) - 80.0;
            },
            slivers: [
              PostsListView(
                postBuilder: (_, i, block) => PostView(
                  key: ValueKey(block.id),
                  block: block,
                  postIndex: i,
                  withCustomVideoPlayer: false,
                ),
                withItemController: true,
                blocks: blocks,
                withLoading: false,
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                scrollOffsetController: _scrollOffsetController,
                scrollOffsetListener: _scrollOffsetListener,
                index: index,
              ),
            ],
          );
        },
      ),
    );
  }
}

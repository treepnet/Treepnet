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
/// By default that rest is the newest posts across everyone, and it keeps
/// paging in more as you scroll to the bottom (so it is not capped at the posts
/// loaded to reach the tapped one). Pass [posts] to scroll through a specific,
/// fixed set instead: a place's grid has to stay inside that place, otherwise
/// tapping a photo of one spot walks you into everyone else's.
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

  static const _pageSize = 50;

  /// The posts currently in the scroll view. Grows as the user scrolls down.
  final List<Post> _posts = [];
  final Set<String> _seenIds = {};

  bool _loading = true; // initial load
  bool _loadingMore = false;
  bool _hasMore = true;
  int _startIndex = 0;

  /// Next DB offset to page from. Tracks rows fetched (not the deduped display
  /// count), so pagination stays aligned with the server even if a duplicate is
  /// dropped on the way in.
  int _nextOffset = 0;

  /// Only the "newest" feed paginates. A passed-in [NewestPostsPage.posts] set
  /// is a complete, bounded list (e.g. one place's posts) and must not grow.
  bool get _paginates => widget.posts == null;

  @override
  void initState() {
    super.initState();
    _itemScrollController = ItemScrollController();
    _itemPositionsListener = ItemPositionsListener.create();
    _scrollOffsetController = ScrollOffsetController();
    _scrollOffsetListener = ScrollOffsetListener.create();
    _itemPositionsListener.itemPositions.addListener(_onPositionsChanged);
    _loadInitial();
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onPositionsChanged);
    super.dispose();
  }

  Future<void> _loadInitial() async {
    List<Post> initial;
    if (widget.posts != null) {
      initial = widget.posts!;
      _hasMore = false;
    } else {
      final (posts, reachedEnd) = await _loadNewestIncluding(
        context.read<PostsRepository>(),
        widget.startPostId,
      );
      initial = posts;
      _hasMore = !reachedEnd;
      _nextOffset = posts.length;
    }
    if (!mounted) return;
    setState(() {
      _addPosts(initial);
      var i = _posts.indexWhere((p) => p.id == widget.startPostId);
      if (i < 0) i = 0;
      _startIndex = i;
      _loading = false;
    });
  }

  /// Loads the newest posts, paging until the tapped post ([startPostId]) is
  /// included, so it can be scrolled to. The explore/trend grid keeps paging in
  /// tiles well past a single page, so a lower tile's post could fall outside a
  /// fixed first-page fetch — and the id lookup would then miss and fall back to
  /// index 0, opening the wrong (first) post. Paging by id (not position) also
  /// stays correct if a new post lands between the grid load and this one.
  /// Bounded so it can never spin. Matches the grid's `created_at DESC` order
  /// (same `getPage`). Returns whether the end of the feed was reached, so the
  /// caller knows if there is more to page in on scroll.
  Future<(List<Post>, bool)> _loadNewestIncluding(
    PostsRepository repo,
    String startPostId,
  ) async {
    final all = <Post>[];
    var reachedEnd = false;
    for (var offset = 0; offset < 1000; offset += _pageSize) {
      final batch = await repo.getPage(offset: offset, limit: _pageSize);
      all.addAll(batch);
      if (batch.length < _pageSize) {
        reachedEnd = true;
        break;
      }
      if (all.any((p) => p.id == startPostId)) break;
    }
    return (all, reachedEnd);
  }

  void _addPosts(Iterable<Post> posts) {
    for (final p in posts) {
      if (_seenIds.add(p.id)) _posts.add(p);
    }
  }

  /// When the user scrolls within a few posts of the end, page in the next 50.
  void _onPositionsChanged() {
    if (!_paginates || _loading || _loadingMore || !_hasMore) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    if (maxIndex >= _posts.length - 5) _loadMore();
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    try {
      final batch = await context.read<PostsRepository>().getPage(
        offset: _nextOffset,
        limit: _pageSize,
      );
      _nextOffset += batch.length;
      if (!mounted) return;
      setState(() {
        _addPosts(batch);
        if (batch.length < _pageSize) _hasMore = false;
      });
    } catch (_) {
      // Keep _hasMore so a later scroll retries.
    } finally {
      _loadingMore = false;
    }
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
      body: _loading
          ? const Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    final blocks = <PostBlock>[
      for (final post in _posts) post.toPostLargeBlock,
    ];

    return InViewNotifierCustomScrollView(
      initialInViewIds: [_startIndex.toString()],
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
          index: _startIndex,
        ),
      ],
    );
  }
}

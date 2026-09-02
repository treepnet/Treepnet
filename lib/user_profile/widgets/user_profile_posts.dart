import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared/shared.dart';

class UserProfilePosts extends StatefulWidget {
  const UserProfilePosts({
    required this.userId,
    required this.index,
    super.key,
  });

  final String userId;
  final int index;

  @override
  State<UserProfilePosts> createState() => _UserProfilePostsState();
}

class _UserProfilePostsState extends State<UserProfilePosts> {
  static const _pageSize = 30;

  late ItemScrollController _itemScrollController;
  late ItemPositionsListener _itemPositionsListener;
  late ScrollOffsetController _scrollOffsetController;
  late ScrollOffsetListener _scrollOffsetListener;

  /// Captured ONCE here, so the scroll listener (which can fire while the page
  /// is being torn down) never does a `context` lookup on a deactivated widget.
  late final UserProfileBloc _bloc;

  /// Reactive window over the profile's posts. Starts wide enough to include
  /// the tapped post (`widget.index` is its position in the full list) plus a
  /// page ahead, then grows by [_pageSize] as the user scrolls to the end —
  /// so a prolific profile isn't loaded and decoded whole.
  int _limit = _pageSize;
  int _requestedLimit = _pageSize;
  Stream<List<PostBlock>>? _stream;
  int _streamLimit = -1;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<UserProfileBloc>();
    _itemScrollController = ItemScrollController();
    _itemPositionsListener = ItemPositionsListener.create();
    _scrollOffsetController = ScrollOffsetController();
    _scrollOffsetListener = ScrollOffsetListener.create();
    _limit = widget.index + _pageSize;
    _requestedLimit = _limit;
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _itemPositionsListener.itemPositions.removeListener(_onScroll);
    super.dispose();
  }

  Stream<List<PostBlock>> _postsStream() {
    if (_stream == null || _streamLimit != _limit) {
      _streamLimit = _limit;
      _stream = _bloc.userPosts(small: false, limit: _limit);
    }
    return _stream!;
  }

  /// Widens the window when the user nears the end of what's loaded. Uses only
  /// captured fields — no `context` — so it's safe to fire during teardown.
  void _onScroll() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    if (maxIndex >= _limit - 5 && _requestedLimit == _limit) {
      _requestedLimit = _limit + _pageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _limit = _requestedLimit);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: InViewNotifierCustomScrollView(
        initialInViewIds: [widget.index.toString()],
        isInViewPortCondition: (deltaTop, deltaBottom, vpHeight) {
          return deltaTop < (0.5 * vpHeight) + 80.0 &&
              deltaBottom > (0.5 * vpHeight) - 80.0;
        },
        slivers: [
          UserProfilePostsAppBar(userId: widget.userId),
          StreamBuilder<List<PostBlock>>(
            stream: _postsStream(),
            builder: (context, snapshot) {
              final blocks = snapshot.data;

              return PostsListView(
                postBuilder: (_, index, block) => PostView(
                  key: ValueKey(block.id),
                  block: block,
                  postIndex: index,
                  withCustomVideoPlayer: false,
                ),
                withItemController: true,
                blocks: blocks,
                withLoading: false,
                itemScrollController: _itemScrollController,
                itemPositionsListener: _itemPositionsListener,
                scrollOffsetController: _scrollOffsetController,
                scrollOffsetListener: _scrollOffsetListener,
                index: widget.index,
              );
            },
          ),
        ],
      ),
    );
  }
}

class UserProfilePostsAppBar extends StatelessWidget {
  const UserProfilePostsAppBar({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UserProfileBloc>();
    final isOwner = context.select((UserProfileBloc b) => b.isOwner);

    late final followText = Padding(
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      child: Tappable.faded(
        onTap: () => bloc.add(const UserProfileFollowUserRequested()),
        child: Text(
          context.l10n.followUser,
          style: context.titleLarge?.copyWith(color: AppColors.blue),
        ),
      ),
    );

    return SliverAppBar(
      centerTitle: false,
      pinned: true,
      actions: [
        BetterStreamBuilder<bool>(
          stream: bloc.followingStatus(),
          builder: (context, isFollowed) {
            if (isFollowed || isOwner) return const SizedBox.shrink();

            return AnimatedSwitcher(
              switchInCurve: Curves.easeIn,
              duration: 550.ms,
              child: isFollowed ? const SizedBox.shrink() : followText,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 1),
                  ),
                  child: child,
                );
              },
            );
          },
        ),
      ],
      title: Text(
        context.l10n.profilePostsAppBarTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/comments/comments.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:treepnet/feed/post/video/video.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/feed_post_line.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' hide VideoPlayer;
import 'package:posts_repository/posts_repository.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

class PostView extends StatelessWidget {
  const PostView({
    required this.block,
    this.builder,
    this.postIndex,
    this.withInViewNotifier = true,
    this.withCustomVideoPlayer = true,
    this.videoPlayerType = VideoPlayerType.feed,
    super.key,
  });

  final PostBlock block;
  final WidgetBuilder? builder;
  final int? postIndex;
  final bool withInViewNotifier;
  final bool withCustomVideoPlayer;
  final VideoPlayerType videoPlayerType;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PostBloc(
        postId: block.id,
        userRepository: context.read<UserRepository>(),
        postsRepository: context.read<PostsRepository>(),
      ),
      child:
          builder?.call(context) ??
          PostLargeView(
            block: block,
            postIndex: postIndex,
            withInViewNotifier: withInViewNotifier,
            withCustomVideoPlayer: withCustomVideoPlayer,
            videoPlayerType: videoPlayerType,
          ),
    );
  }
}

class PostLargeView extends StatefulWidget {
  const PostLargeView({
    required this.block,
    required this.postIndex,
    required this.withInViewNotifier,
    required this.withCustomVideoPlayer,
    required this.videoPlayerType,
    super.key,
  });

  final PostBlock block;
  final int? postIndex;
  final bool withInViewNotifier;
  final bool withCustomVideoPlayer;
  final VideoPlayerType videoPlayerType;

  @override
  State<PostLargeView> createState() => _PostLargeViewState();
}

class _PostLargeViewState extends State<PostLargeView> {
  void _navigateToPostAuthor(
    BuildContext context, {
    required String id,
    UserProfileProps? props,
  }) => context.pushNamed(
    AppRoutes.userProfile.name,
    pathParameters: {'user_id': id},
    extra: props,
  );

  /// The comments of this post, or of [block] (another of its author's,
  /// opened on the new feed's globe).
  void _openComments(
    BuildContext context, {
    required bool showFullSized,
    PostBlock? block,
  }) => context.showScrollableModal(
    showFullSized: showFullSized,
    pageBuilder: (scrollController, draggableScrollController) => CommentsPage(
      post: block ?? widget.block,
      scrollController: scrollController,
      draggableScrollController: draggableScrollController,
    ),
  );

  /// Shares this post, or [block] (as [_openComments]).
  void _openShare(BuildContext context, {PostBlock? block}) =>
      context.showScrollableModal(
        pageBuilder: (scrollController, draggableScrollController) => SharePost(
          block: block ?? widget.block,
          scrollController: scrollController,
          draggableScrollController: draggableScrollController,
        ),
      );

  void _handleOnPostTap(BuildContext context, {required BlockAction action}) =>
      action.when(
        navigateToPostAuthor: (action) =>
            _navigateToPostAuthor(context, id: action.authorId),
        navigateToSponsoredPostAuthor: (action) => _navigateToPostAuthor(
          context,
          id: action.authorId,
          props: UserProfileProps.build(
            isSponsored: true,
            promoBlockAction: action,
            sponsoredPost: widget.block as PostSponsoredBlock,
          ),
        ),
      );

  @override
  void initState() {
    super.initState();
    context.read<PostBloc>()..add(
      PostStatsSubscriptionRequested(
        ownerId: widget.block.author.id,
        currentUserId: context.read<AppBloc>().state.user.id,
      ),
    );
    // No "liked by … you follow" request any more: the card never showed it,
    // and each card asked the server again whenever it scrolled back into
    // view (a third of all API calls).
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PostBloc>();

    final isOwner = context.select((PostBloc bloc) => bloc.state.isOwner);
    final isLiked = context.select((PostBloc bloc) => bloc.state.isLiked);
    final isBookmarked = context.select(
      (PostBloc bloc) => bloc.state.isBookmarked,
    );
    final isFollowed = context.select((PostBloc bloc) => bloc.state.isFollowed);
    final commentsCount = context.select(
      (PostBloc bloc) => bloc.state.commentsCount,
    );
    final authorTier = context.select((PostBloc bloc) => bloc.state.authorTier);
    final authorPlaces = context.select(
      (PostBloc bloc) => bloc.state.authorPlaces,
    );
    // The new feed and Trends' Maps tab: the author's globe, facing the
    // post's place, in place of the photos, the post's buttons on its card.
    final globeMode = FeedGlobeMode.maybeOf(context);
    final globe = globeMode != null;

    return PostLarge(
      block: widget.block,
      isOwner: isOwner,
      isLiked: isLiked,
      likePost: () => bloc.add(const PostLikeRequested()),
      likeByDoubleTap: () => bloc.add(const PostLikeRequested(liked: true)),
      isBookmarked: isBookmarked,
      bookmarkPost: () => bloc.add(const PostBookmarkRequested()),
      isFollowed: isOwner || (isFollowed ?? true),
      follow: () =>
          bloc.add(PostAuthorFollowRequested(authorId: widget.block.author.id)),
      enableFollowButton: true,
      commentsCount: commentsCount,
      postIndex: widget.postIndex,
      withInViewNotifier: widget.withInViewNotifier,
      likesCountBuilder: (onUserTap) =>
          PostLikesCount(block: widget.block, onUserTap: onUserTap),
      authorBadge: TravelTierBadge.tier(authorTier),
      authorSubtitle: _AuthorLocationCount(count: authorPlaces),
      mediaReplacement: globe
          // The likes count is the globe card's alone: only it rebuilds when
          // someone likes the post (the usual card shows its likers).
          ? BlocSelector<PostBloc, PostState, int>(
              selector: (state) => state.likes,
              builder: (context, likesCount) => FeedPostGlobe(
                block: widget.block,
                isLiked: isLiked,
                isBookmarked: isBookmarked,
                commentsCount: commentsCount,
                likesCount: likesCount,
                onLikeTap: () => bloc.add(const PostLikeRequested()),
                // This post's, or another of its author's grown on the globe.
                onShareTap: (block) => _openShare(context, block: block),
                onCommentsTap: (block) =>
                    _openComments(context, showFullSized: true, block: block),
                onSaveTap: () => bloc.add(const PostBookmarkRequested()),
              ),
            )
          : null,
      // On a globe, the description goes up beside the arrows (below), or
      // nowhere (Trends).
      showCaption: !globe,
      // Its time under its description; with none, up beside the arrows
      // (below) instead; on Trends' Maps tab, nowhere. Spaces alone are no
      // description (as the line beside the arrows reads it).
      showTime:
          globeMode == null ||
          (globeMode.showCaption && widget.block.caption.trim().isNotEmpty),
      // The buttons are on the globe's card: where they were, the arrows to
      // the next post and the one before, and the description (or the time)
      // beside them.
      footerInPlaceOfActions: globe
          ? FeedPostLine(
              block: widget.block,
              mode: globeMode,
              postIndex: widget.postIndex,
            )
          : null,
      postAuthorAvatarBuilder: (context, author, onAvatarTap) {
        return UserStoriesAvatar(
          resizeHeight: 108,
          tappableVariant: TappableVariant.scaled,
          author: author.toUser,
          onAvatarTap: onAvatarTap,
          enableInactiveBorder: false,
          withAdaptiveBorder: false,
        );
      },
      postOptionsSettings: isOwner
          ? PostOptionsSettings.owner(
              onPostEdit: (block) => context.pushNamed(
                AppRoutes.postEdit.name,
                pathParameters: {'post_id': block.id},
                extra: block,
              ),
              onPostDelete: (_) {
                bloc.add(const PostDeleteRequested());
                context.read<FeedBloc>().add(
                  FeedUpdateRequested(
                    update: FeedPageUpdate(
                      newPost: widget.block.toPost,
                      type: PageUpdateType.delete,
                    ),
                  ),
                );
              },
              onPostArchive: (postId) {
                context.read<PostsRepository>().archivePost(postId: postId);
                context.read<FeedBloc>().add(
                  FeedUpdateRequested(
                    update: FeedPageUpdate(
                      newPost: widget.block.toPost,
                      type: PageUpdateType.delete,
                    ),
                  ),
                );
                openSnackbar(
                  SnackbarMessage.success(title: context.l10n.postArchivedText),
                );
              },
            )
          : PostOptionsSettings.viewer(
              // "Don't show again": out of this user's feed, now and later.
              onPostHide: () {
                context.read<PostsRepository>().hidePost(
                  postId: widget.block.id,
                );
                context.read<FeedBloc>().add(
                  FeedUpdateRequested(
                    update: FeedPageUpdate(
                      newPost: widget.block.toPost,
                      type: PageUpdateType.delete,
                    ),
                  ),
                );
                openSnackbar(
                  SnackbarMessage.success(title: context.l10n.postHiddenText),
                );
              },
              // The same block as on the profile (the menu confirms first).
              onAuthorBlock: () async {
                await context.read<UserRepository>().blockUser(
                  userId: context.read<AppBloc>().state.user.id,
                  blockedId: widget.block.author.id,
                );
                if (!context.mounted) return;
                context.read<SearchRepository>().clearCache();
                context.read<FeedBloc>().add(const FeedRefreshRequested());
                openSnackbar(
                  SnackbarMessage.success(title: context.l10n.blockedText),
                  clearIfQueue: true,
                );
              },
            ),
      onCommentsTap: (showFullSized) =>
          _openComments(context, showFullSized: showFullSized),
      onUserTap: (userId) => _navigateToPostAuthor(context, id: userId),
      onPressed: (action) => _handleOnPostTap(context, action: action),
      onPostShareTap: (postId, author) => _openShare(context),
      videoPlayerBuilder: !widget.withCustomVideoPlayer
          ? null
          : (_, media, aspectRatio, isInView) => PostVideoPlayer(
              videoPlayerType: widget.videoPlayerType,
              media: media,
              aspectRatio: aspectRatio,
              isInView: isInView,
            ),
    );
  }
}

/// The author's total distinct visited-region count, shown as a small line
/// under their name in the post header (a travel-app twist on the usual
/// location subtitle).
class _AuthorLocationCount extends StatelessWidget {
  const _AuthorLocationCount({required this.count});

  /// Every pinned post counts, not the distinct regions they fall in —
  /// 28 posts across 9 provinces reads as "28 locations", not "9". Comes
  /// with the post's stats (PostStats.authorPlaces).
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Text(
      context.l10n.locationsCountText(count),
      style: context.bodySmall?.copyWith(color: AppColors.textSecondary),
    );
  }
}

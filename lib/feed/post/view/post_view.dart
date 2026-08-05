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
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' hide VideoPlayer;
import 'package:posts_repository/posts_repository.dart';
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
    context.read<PostBloc>()
      ..add(const PostLikesCountSubscriptionRequested())
      ..add(const PostCommentsCountSubscriptionRequested())
      ..add(const PostIsLikedSubscriptionRequested())
      ..add(const PostIsBookmarkedSubscriptionRequested())
      ..add(
        PostAuthorFollowingStatusSubscriptionRequested(
          ownerId: widget.block.author.id,
          currentUserId: context.read<AppBloc>().state.user.id,
        ),
      )
      ..add(const PostLikersInFollowingsFetchRequested());
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

    return PostLarge(
      block: widget.block,
      isOwner: isOwner,
      isLiked: isLiked,
      likePost: () => bloc.add(const PostLikeRequested()),
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
      likersInFollowingsBuilder: PostLikersInFollowings.new,
      authorBadge: TravelTierBadge(userId: widget.block.author.id),
      authorSubtitle: _AuthorLocationCount(userId: widget.block.author.id),
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
                  SnackbarMessage.success(
                    title: context.l10n.postArchivedText,
                  ),
                );
              },
            )
          : const PostOptionsSettings.viewer(),
      onCommentsTap: (showFullSized) => context.showScrollableModal(
        showFullSized: showFullSized,
        pageBuilder: (scrollController, draggableScrollController) =>
            CommentsPage(
              post: widget.block,
              scrollController: scrollController,
              draggableScrollController: draggableScrollController,
            ),
      ),
      onUserTap: (userId) => _navigateToPostAuthor(context, id: userId),
      onPressed: (action) => _handleOnPostTap(context, action: action),
      onPostShareTap: (postId, author) => context.showScrollableModal(
        pageBuilder: (scrollController, draggableScrollController) => SharePost(
          block: widget.block,
          scrollController: scrollController,
          draggableScrollController: draggableScrollController,
        ),
      ),
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
  const _AuthorLocationCount({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    // Every pinned post counts, not the distinct regions they fall in —
    // 28 posts across 9 provinces reads as "28 locations", not "9".
    return StreamBuilder<List<({double lat, double lng, String? name})>>(
      stream: context.read<PostsRepository>().visitedPointsOf(userId: userId),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return Text(
          count == 1 ? '1 location' : '$count locations',
          style: context.bodySmall?.copyWith(color: AppColors.textSecondary),
        );
      },
    );
  }
}

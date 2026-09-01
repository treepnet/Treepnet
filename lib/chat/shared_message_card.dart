import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/routes/app_routes.dart';
import 'package:treepnet/chat/chat_share_ref.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/widgets/stories_props.dart';

/// The `sharedMessageBuilder` handed to the chat plugin. Returns a rich card
/// for a share-sentinel message, or `null` for plain text (rendered normally).
Widget? buildSharedMessage(BuildContext context, String content) {
  final ref = parseSharedRef(content);
  if (ref == null) return null;
  return switch (ref.kind) {
    SharedRefKind.post => _SharedPostCard(postId: ref.id),
    SharedRefKind.story => _SharedStoryCard(storyId: ref.id),
  };
}

/// Flat grey card body — matches the message bubbles.
const _cardColor = Color(0xff414141);
const _captionColor = Color(0xff9AA6A6);

/// A large Instagram-style shared post: author header, a big square media
/// preview and the caption — fetched by id from the local repository and
/// rendered by reference (no media copy). Tapping opens the post.
class _SharedPostCard extends StatefulWidget {
  const _SharedPostCard({required this.postId});

  final String postId;

  @override
  State<_SharedPostCard> createState() => _SharedPostCardState();
}

class _SharedPostCardState extends State<_SharedPostCard> {
  late Future<Post?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PostsRepository>().getPostBy(id: widget.postId);
  }

  void _open() => context.pushNamed(
    AppRoutes.post.name,
    pathParameters: {'id': widget.postId},
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Post?>(
    future: _future,
    builder: (context, snapshot) {
      final post = snapshot.data;
      final loading = snapshot.connectionState == ConnectionState.waiting;
      final media = post?.media ?? const <Media>[];
      final thumbUrl = media.isNotEmpty ? media.first.url : null;

      return _CardShell(
        onTap: post == null ? null : _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Author header.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: UserProfileAvatar(
                      avatarUrl: post?.author.avatarUrl,
                      isLarge: false,
                      radius: 16,
                      enableBorder: false,
                    ),
                  ),
                  const Gap.h(AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loading
                          ? '…'
                          : (post?.author.displayUsername ??
                                context.l10n.postText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Big square media preview.
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Media(url: thumbUrl, loading: loading),
                  ),
                  if (media.length > 1)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.collections,
                        color: Colors.white,
                        size: 22,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                ],
              ),
            ),
            // Caption.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                loading
                    ? ''
                    : (post == null
                          ? context.l10n.postUnavailableText
                          : (post.caption.trim().isNotEmpty
                                ? post.caption
                                : context.l10n.openPostText)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _captionColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// A large shared story — same layout as the post card: author header, a big
/// square media preview and a label. Fetched by id; tapping opens the story
/// viewer.
class _SharedStoryCard extends StatefulWidget {
  const _SharedStoryCard({required this.storyId});

  final String storyId;

  @override
  State<_SharedStoryCard> createState() => _SharedStoryCardState();
}

class _SharedStoryCardState extends State<_SharedStoryCard> {
  late Future<Story?> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StoriesRepository>().getStoryBy(id: widget.storyId);
  }

  void _open(Story story) => context.pushNamed(
    AppRoutes.stories.name,
    pathParameters: {'user_id': story.author.id},
    extra: StoriesProps(stories: [story], author: story.author),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Story?>(
    future: _future,
    builder: (context, snapshot) {
      final story = snapshot.data;
      final loading = snapshot.connectionState == ConnectionState.waiting;
      final isVideo = story?.contentType == StoryContentType.video;

      return _CardShell(
        onTap: story == null ? null : () => _open(story),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: UserProfileAvatar(
                      avatarUrl: story?.author.avatarUrl,
                      isLarge: false,
                      radius: 16,
                      enableBorder: false,
                    ),
                  ),
                  const Gap.h(AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loading
                          ? '…'
                          : (story?.author.displayUsername ??
                                context.l10n.storyText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: _Media(
                      url: loading ? null : story?.contentUrl,
                      loading: loading,
                    ),
                  ),
                  if (isVideo)
                    const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 44,
                      shadows: [Shadow(blurRadius: 4)],
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                loading
                    ? ''
                    : (story == null
                          ? context.l10n.storyUnavailableText
                          : context.l10n.storyText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _captionColor, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The rounded card container, sized to a large fraction of the screen so the
/// media preview reads as a proper post (not a tiny thumbnail).
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: context.screenWidth * 0.72,
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(18),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class _Media extends StatelessWidget {
  const _Media({required this.url, required this.loading});

  final String? url;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      color: const Color(0xff2A2A2A),
      alignment: Alignment.center,
      child: const Icon(Icons.grid_on, color: _captionColor, size: 40),
    );

    if (loading) return const ColoredBox(color: Color(0xff2A2A2A));
    if (url == null || url!.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => fallback(),
      placeholder: (_, __) => const ColoredBox(color: Color(0xff2A2A2A)),
    );
  }
}

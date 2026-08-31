import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/routes/app_routes.dart';
import 'package:treepnet/chat/chat_share_ref.dart';

/// The `sharedMessageBuilder` handed to the chat plugin. Returns a rich card
/// for a share-sentinel message, or `null` for plain text (rendered normally).
Widget? buildSharedMessage(BuildContext context, String content) {
  final ref = parseSharedRef(content);
  if (ref == null) return null;
  return switch (ref.kind) {
    SharedRefKind.post => _SharedPostCard(postId: ref.id),
    SharedRefKind.story => const _SharedStoryCard(),
  };
}

const _cardColor = Color(0xff2A2A2A);
const _cardWidth = 260.0;

/// A shared post — fetched by id from the local repository and rendered by
/// reference (no media copy). Tapping opens the post.
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
      final thumbUrl = (post?.media.isNotEmpty ?? false)
          ? post!.media.first.url
          : null;

      return _CardShell(
        onTap: post == null ? null : _open,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(url: thumbUrl, loading: loading, icon: Icons.grid_on),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loading
                          ? '…'
                          : (post == null
                                ? 'Post mavjud emas'
                                : post.author.displayUsername),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      loading
                          ? ''
                          : (post?.caption.isNotEmpty ?? false
                                ? post!.caption
                                : 'Postni ochish'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xff9AA6A6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 8),
              child: Icon(Icons.chevron_right, color: Color(0xff687575)),
            ),
          ],
        ),
      );
    },
  );
}

/// A shared story. Stories have no fetch-by-id/route yet, so this is a simple
/// labelled card (Phase 3 can enrich it once a story-by-id view exists).
class _SharedStoryCard extends StatelessWidget {
  const _SharedStoryCard();

  @override
  Widget build(BuildContext context) => _CardShell(
    child: Row(
      children: [
        const _Thumb(url: null, loading: false, icon: Icons.auto_stories),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Story',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ulashilgan story',
                  style: TextStyle(color: Color(0xff9AA6A6), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
  );
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: _cardWidth),
    decoration: BoxDecoration(
      color: _cardColor,
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: child),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.loading, required this.icon});

  final String? url;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    Widget fallback() => Container(
      width: size,
      height: size,
      color: const Color(0xff414141),
      child: Icon(icon, color: const Color(0xff9AA6A6), size: 26),
    );

    if (loading) {
      return const SizedBox(
        width: size,
        height: size,
        child: ColoredBox(color: Color(0xff414141)),
      );
    }
    if (url == null || url!.isEmpty) return fallback();
    return CachedNetworkImage(
      imageUrl: url!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => fallback(),
      placeholder: (_, __) => fallback(),
    );
  }
}

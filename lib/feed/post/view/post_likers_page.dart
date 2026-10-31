import 'package:app_ui/app_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/app/services/pager.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template post_likers_page}
/// The list of everyone who liked a post, opened by tapping the post's likes
/// count. Each row shows the user with a live Follow button and taps through to
/// their profile.
/// {@endtemplate}
class PostLikersPage extends StatefulWidget {
  /// {@macro post_likers_page}
  const PostLikersPage({required this.postId, super.key});

  /// The post whose likers are listed.
  final String postId;

  @override
  State<PostLikersPage> createState() => _PostLikersPageState();
}

class _PostLikersPageState extends State<PostLikersPage> {
  /// 30 at a time as the list is scrolled (it used to stop at 100).
  late final _likers = Pager<User>(
    fetch: (offset, limit) => context.read<PostsRepository>().getPostLikers(
      postId: widget.postId,
      offset: offset,
      limit: limit,
    ),
    idOf: (user) => user.id,
  );

  @override
  void initState() {
    super.initState();
    _likers.refresh();
  }

  @override
  void dispose() {
    _likers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: AppColors.transparent,
        appBar: AppBar(
          backgroundColor: AppColors.transparent,
          surfaceTintColor: AppColors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.likesText,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        body: ListenableBuilder(
          listenable: _likers,
          builder: (context, _) {
            if (_likers.loading) {
              return const Center(child: AppCircularProgress(AppColors.blue));
            }
            final users = _likers.items;
            if (users.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.noLikesYetText,
                  style: context.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 600) {
                  _likers.loadMore();
                }
                return false;
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: users.length + (_likers.loadingMore ? 1 : 0),
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 76,
                  color: AppColors.divider,
                ),
                itemBuilder: (context, i) => i == users.length
                    ? const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: AppCircularProgress(AppColors.blue),
                        ),
                      )
                    : _LikerTile(user: users[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LikerTile extends StatelessWidget {
  const _LikerTile({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final avatar = user.avatarUrl;
    return ListTile(
      onTap: () => context.pushNamed(
        AppRoutes.userProfile.name,
        pathParameters: {'user_id': user.id},
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.glassBackgroundLight,
        // Cached, and decoded at about 3x the 48px circle (a NetworkImage
        // re-downloaded it and decoded the full photo).
        backgroundImage: (avatar != null && avatar.isNotEmpty)
            ? ResizeImage(CachedNetworkImageProvider(avatar), width: 144)
            : null,
        child: (avatar == null || avatar.isEmpty)
            ? Icon(Icons.person, color: AppColors.textSecondary)
            : null,
      ),
      title: Text(
        user.displayUsername,
        style: context.textTheme.titleMedium?.copyWith(
          color: context.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.displayFullName,
        style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

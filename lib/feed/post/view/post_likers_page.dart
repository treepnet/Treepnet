import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/app/app.dart';
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
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<PostsRepository>().getPostLikers(
      postId: widget.postId,
      offset: 0,
      limit: 100,
    );
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
        body: FutureBuilder<List<User>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppCircularProgress(AppColors.blue));
            }
            final users = snapshot.data ?? const <User>[];
            if (users.isEmpty) {
              return Center(
                child: Text(
                  context.l10n.noLikesYetText,
                  style: context.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: AppColors.divider,
              ),
              itemBuilder: (context, i) => _LikerTile(user: users[i]),
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
    final me = context.read<UserRepository>().currentUserId;
    return ListTile(
      onTap: () => context.pushNamed(
        AppRoutes.userProfile.name,
        pathParameters: {'user_id': user.id},
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.glassBackgroundLight,
        backgroundImage: (avatar != null && avatar.isNotEmpty)
            ? NetworkImage(avatar)
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
      // No follow button for the current user's own row.
      trailing: user.id == me ? null : _FollowButton(userId: user.id),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<UserRepository>();
    return StreamBuilder<bool>(
      stream: repo.followingStatus(userId: userId),
      initialData: false,
      builder: (context, snapshot) {
        final following = snapshot.data ?? false;
        if (following) {
          return OutlinedButton(
            onPressed: () => repo.unfollow(unfollowId: userId),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colorScheme.onSurface,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              minimumSize: const Size(0, 34),
            ),
            child: Text(context.l10n.followingUser),
          );
        }
        return ElevatedButton(
          onPressed: () => repo.follow(followToId: userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: AppColors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xlg),
            minimumSize: const Size(0, 34),
          ),
          child: Text(context.l10n.followUser),
        );
      },
    );
  }
}

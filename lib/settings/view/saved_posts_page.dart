import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:insta_blocks/insta_blocks.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template saved_posts_page}
/// The "Saved" collection (Settings → Saved). Shows a 3-column grid of the
/// posts the current user has bookmarked, newest first.
/// {@endtemplate}
class SavedPostsPage extends StatefulWidget {
  /// {@macro saved_posts_page}
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  late Future<List<Post>> _future;

  /// Subscribed to by hand rather than through a `StreamBuilder`. PowerSync's
  /// `watch` is single-subscription, so a rebuilt tab re-listened to it and
  /// threw "Stream has already been listened to"; making it broadcast instead
  /// dropped the first event and left the tab spinning forever. One
  /// subscription, held in state, does neither.
  StreamSubscription<List<User>>? _profilesSub;
  List<User>? _profiles;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _profilesSub ??= context
        .read<UserRepository>()
        .savedProfilesOf(userId: context.read<AppBloc>().state.user.id)
        .listen((rows) {
          if (mounted) setState(() => _profiles = rows);
        });
  }

  @override
  void dispose() {
    _profilesSub?.cancel();
    super.dispose();
  }

  Future<List<Post>> _load() =>
      context.read<PostsRepository>().getSavedPosts(offset: 0, limit: 80);

  Future<void> _refresh() async {
    final reloaded = _load();
    setState(() => _future = reloaded);
    await reloaded;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: TreepNetAmbientBackground(
        child: AppScaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: context.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              context.l10n.savedText,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colorScheme.onSurface,
              ),
            ),
            bottom: TabBar(
              tabs: [
                Tab(text: context.l10n.postsText),
                Tab(text: context.l10n.profileText),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _postsTab(context),
              _profilesTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _postsTab(BuildContext context) {
    return FutureBuilder<List<Post>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: AppCircularProgress(context.colorScheme.primary));
        }
        final posts = snapshot.data ?? const <Post>[];
        if (posts.isEmpty) return const _EmptySaved();

        final blocks = posts.map((p) => p.toPostSmallBlock).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: GridView.builder(
            padding: EdgeInsets.zero,
            // Same tiles as the Trends grid.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 133 / 170,
            ),
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              final block = blocks[index];
              if (block.firstMediaUrl == null) {
                return const SizedBox.shrink();
              }
              return Tappable.faded(
                onTap: () => context.pushNamed(
                  AppRoutes.post.name,
                  pathParameters: {'id': block.id},
                ),
                child: _SavedThumbnail(block: block),
              );
            },
          ),
        );
      },
    );
  }

  Widget _profilesTab(BuildContext context) {
    final users = _profiles;
    if (users == null) {
      return Center(child: AppCircularProgress(context.colorScheme.primary));
    }
    if (users.isEmpty) return const _EmptySavedProfiles();
    return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: users.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            indent: 76,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              leading: UserProfileAvatar(
                avatarUrl: user.avatarUrl,
                isLarge: false,
                radius: 22,
                enableBorder: false,
              ),
              // Username only. The display name sat above it and said the same
              // thing twice for most people.
              title: Text(
                user.displayUsername,
                style: context.bodyLarge?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
              trailing: Tappable.scaled(
                onTap: () => context.confirmAction(
                  title: context.l10n.removeFromSavedText,
                  content: context.l10n.removeFromSavedConfirmText(
                    user.displayUsername,
                  ),
                  noText: context.l10n.cancelText,
                  yesText: context.l10n.removeText,
                  yesTextStyle: const TextStyle(color: AppColors.red),
                  fn: () => context.read<UserRepository>().unsaveProfile(
                    userId: context.read<AppBloc>().state.user.id,
                    profileId: user.id,
                  ),
                ),
                child: Assets.icons.savedFilled.svg(
                  width: AppSize.iconSizeMedium,
                  height: AppSize.iconSizeMedium,
                  colorFilter: const ColorFilter.mode(
                    AppColors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              onTap: () => context.pushNamed(
                AppRoutes.userProfile.name,
                pathParameters: {'user_id': user.id},
              ),
            );
          },
        );
  }
}

class _SavedThumbnail extends StatelessWidget {
  const _SavedThumbnail({required this.block});

  final PostBlock block;

  @override
  Widget build(BuildContext context) {
    return BlurHashImageThumbnail(
      id: block.id,
      decodeWidth: 480,
      url: block.firstMediaUrl ?? '',
      blurHash: block.firstMedia?.blurHash,
    );
  }
}

class _EmptySavedProfiles extends StatelessWidget {
  const _EmptySavedProfiles();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassBackgroundLight,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.textSecondary,
                size: 46,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.noSavedProfilesText,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.savedProfilesHintText,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySaved extends StatelessWidget {
  const _EmptySaved();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xlg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glassBackgroundLight,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                color: AppColors.textSecondary,
                size: 46,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.nothingSavedText,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.savedPostsHintText,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

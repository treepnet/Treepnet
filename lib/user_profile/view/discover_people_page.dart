import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template discover_people_page}
/// "Discover people" — a list of accounts the current user does not follow yet,
/// each with a live Follow button and a tap-through to their profile. Opened
/// from the suggested-people button on the profile header.
/// {@endtemplate}
class DiscoverPeoplePage extends StatefulWidget {
  /// {@macro discover_people_page}
  const DiscoverPeoplePage({super.key});

  @override
  State<DiscoverPeoplePage> createState() => _DiscoverPeoplePageState();
}

class _DiscoverPeoplePageState extends State<DiscoverPeoplePage> {
  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<UserRepository>().suggestedUsers();
  }

  Future<void> _refresh() async {
    final reloaded = context.read<UserRepository>().suggestedUsers();
    setState(() => _future = reloaded);
    await reloaded;
  }

  @override
  Widget build(BuildContext context) {
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.discoverPeopleText,
            style: context.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        body: FutureBuilder<List<User>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            final users = snapshot.data ?? const <User>[];
            if (users.isEmpty) return const _EmptyDiscover();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: users.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 76,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                itemBuilder: (context, i) => _PersonTile(user: users[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.user});

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
        backgroundColor: Colors.white.withValues(alpha: 0.1),
        backgroundImage: (avatar != null && avatar.isNotEmpty)
            ? NetworkImage(avatar)
            : null,
        child: (avatar == null || avatar.isEmpty)
            ? const Icon(Icons.person, color: Colors.white54)
            : null,
      ),
      title: Text(
        user.displayUsername,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        user.displayFullName,
        style: const TextStyle(color: Colors.white54),
      ),
      trailing: _FollowButton(userId: user.id),
    );
  }
}

/// Live Follow / Following toggle for a single suggested user.
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
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 34),
            ),
            child: Text(context.l10n.followingUser),
          );
        }
        return ElevatedButton(
          onPressed: () => repo.follow(followToId: userId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.white,
            foregroundColor: AppColors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            minimumSize: const Size(0, 34),
          ),
          child: Text(context.l10n.followUser),
        );
      },
    );
  }
}

class _EmptyDiscover extends StatelessWidget {
  const _EmptyDiscover();

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
                color: Colors.white.withValues(alpha: 0.06),
              ),
              child: const Icon(
                Icons.person_add_alt_1_outlined,
                color: Colors.white54,
                size: 44,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.noSuggestionsText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            const Text(
              "You're following everyone we could find. Check back later.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

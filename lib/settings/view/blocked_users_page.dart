import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// {@template blocked_users_page}
/// Settings → Blocked users. Lists everyone the current user has blocked and
/// lets them unblock with a tap.
/// {@endtemplate}
class BlockedUsersPage extends StatelessWidget {
  /// {@macro blocked_users_page}
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AppBloc>().state.user.id;
    final repo = context.read<UserRepository>();
    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colorScheme.onSurface),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            context.l10n.blockedUsersText,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.colorScheme.onSurface,
            ),
          ),
        ),
        body: StreamBuilder<List<User>>(
          stream: repo.blockedUsers(userId: userId),
          builder: (context, snapshot) {
            final users = snapshot.data;
            if (users == null) {
              return Center(child: AppCircularProgress(context.colorScheme.primary));
            }
            if (users.isEmpty) return const _EmptyBlocked();
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color: AppColors.divider,
              ),
              itemBuilder: (context, i) {
                final user = users[i];
                final avatar = user.avatarUrl;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.glassBackgroundLight,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? const Icon(Icons.person, color: AppColors.textSecondary)
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
                  trailing: TextButton(
                    onPressed: () => repo.unblockUser(
                      userId: userId,
                      blockedId: user.id,
                    ),
                    child: Text(context.l10n.unblockText),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptyBlocked extends StatelessWidget {
  const _EmptyBlocked();

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
                Icons.block,
                color: AppColors.textSecondary,
                size: 46,
              ),
            ),
            const Gap.v(AppSpacing.lg),
            Text(
              context.l10n.noBlockedUsersText,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.blockedUsersHintText,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

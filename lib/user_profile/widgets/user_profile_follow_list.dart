import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/user_profile.dart';

/// A profile's followers ([followers]) or followings, a page at a time.
///
/// It was a bare list: blank while loading, when empty, offline or for a
/// private account (whose lists the server returns empty).
class UserProfileFollowList extends StatefulWidget {
  const UserProfileFollowList({required this.followers, super.key});

  final bool followers;

  @override
  State<UserProfileFollowList> createState() => _UserProfileFollowListState();
}

class _UserProfileFollowListState extends State<UserProfileFollowList>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => context.read<UserProfileBloc>().add(
    widget.followers
        ? const UserProfileFollowersSubscriptionRequested()
        : const UserProfileFollowingsListRequested(),
  );

  void _more() => context.read<UserProfileBloc>().add(
    UserProfileFollowListMoreRequested(followers: widget.followers),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final followers = widget.followers;
    final access = context.select((UserProfileBloc b) => b.state.access);
    final users = context.select(
      (UserProfileBloc b) =>
          followers ? b.state.followers : b.state.followings,
    );
    final status = context.select(
      (UserProfileBloc b) =>
          followers ? b.state.followersStatus : b.state.followingsStatus,
    );
    final end = context.select(
      (UserProfileBloc b) =>
          followers ? b.state.followersEnd : b.state.followingsEnd,
    );
    final l10n = context.l10n;

    final Widget? message = switch (access) {
      ProfileAccess.locked || ProfileAccess.blockedByOwner => _Message(
        icon: Icons.lock_outline,
        title: l10n.privateAccountTitle,
        text: l10n.privateAccountSubtitle,
      ),
      _ when users.isNotEmpty => null,
      _ => switch (status) {
        FollowListStatus.loading => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        FollowListStatus.failed => LoadFailed(onRetry: _load),
        FollowListStatus.done => _Message(
          icon: Icons.people_outline,
          title: followers ? l10n.noFollowersText : l10n.noFollowingsText,
        ),
      },
    };

    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        if (message != null)
          SliverFillRemaining(hasScrollBody: false, child: message)
        else
          SliverList.builder(
            itemCount: users.length + (end ? 0 : 1),
            itemBuilder: (context, index) {
              if (index < users.length) {
                final user = users[index];
                // Keyed by the person: when the list shifts (someone
                // removed), a row keeps its own follow state.
                return UserProfileListTile(
                  key: ValueKey(user.id),
                  user: user,
                  follower: followers,
                );
              }
              // The foot: the next page, asked for once it comes into view.
              if (status == FollowListStatus.failed) {
                return Center(
                  child: TextButton(
                    onPressed: _more,
                    child: Text(l10n.retryText),
                  ),
                );
              }
              if (status == FollowListStatus.done) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _more();
                });
              }
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.text});

  final IconData icon;
  final String title;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xlg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 44),
          const Gap.v(AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (text != null) ...[
            const Gap.v(AppSpacing.sm),
            Text(
              text!,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ignore_for_file: lines_longer_than_80_chars

import 'dart:ui';
import 'package:app_ui/app_ui.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/location_picker_map.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:treepnet/settings/view/settings_page.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:treepnet/user_profile/widgets/story_highlights_row.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:sliver_tools/sliver_tools.dart';
import 'package:user_repository/user_repository.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({
    required this.userId,
    this.props = const UserProfileProps.build(),
    super.key,
  });

  final String userId;
  final UserProfileProps props;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              UserProfileBloc(
                  userId: userId,
                  postsRepository: context.read<PostsRepository>(),
                  userRepository: context.read<UserRepository>(),
                )
                ..add(const UserProfileSubscriptionRequested())
                ..add(const UserProfilePostsCountSubscriptionRequested())
                ..add(const UserProfileFollowingsCountSubscriptionRequested())
                ..add(const UserProfileFollowersCountSubscriptionRequested()),
        ),
      ],
      child: UserProfileView(userId: userId, props: props),
    );
  }
}

class UserProfileView extends StatefulWidget {
  const UserProfileView({required this.props, required this.userId, super.key});

  final String userId;
  final UserProfileProps props;

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView>
    with SingleTickerProviderStateMixin {
  late ScrollController _controller;

  /// Stable identity for the posts grid across rebuilds.
  final Key _gridKey = UniqueKey();

  UserProfileProps get props => widget.props;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    final promoAction =
        props.promoBlockAction as NavigateToSponsoredPostAuthorProfileAction?;
    final user = context.select((UserProfileBloc bloc) => bloc.state.user);

    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: !props.isSponsored
            ? null
            : PromoFloatingAction(
                url: promoAction!.promoUrl,
                promoImageUrl: promoAction.promoPreviewImageUrl,
                title: context.l10n.learnMoreAboutUserPromoText,
                subtitle: context.l10n.visitUserPromoWebsiteText,
              ),
        body: DefaultTabController(
          length: 2,
          // Open on the Map tab; the user taps into Posts themselves.
          initialIndex: 0,
          child: Builder(
            builder: (tabContext) {
              final tabController = DefaultTabController.of(tabContext);
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  // On the map (globe) tab lock the page scroll + tab-swipe so
                  // the map owns all pan/zoom gestures (Google-Maps style).
                  final onMap = tabController.index == 0;
                  // But locking the scroll while the header is collapsed traps
                  // it there — the map fills the screen and the tab bar is gone,
                  // with no way back. So on entering the map tab, snap the
                  // header (and tab bar) back into view first.
                  if (onMap) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_controller.hasClients && _controller.offset != 0) {
                        _controller.jumpTo(0);
                      }
                    });
                  }
                  Widget buildScaffold(bool tabsHidden) {
                    // No pull-to-refresh on the profile — the header, counts and
                    // grid are all live streams, so there is nothing to re-fetch.
                    return NestedScrollView(
                      // Keep the OUTER scroll live on both tabs so the profile
                      // header can be collapsed (map pushed to full-screen) the
                      // moment the profile opens — not only after a round-trip
                      // through the Posts tab. The map keeps its own pan/zoom
                      // because the horizontal tab-swipe stays locked below.
                      physics: null,
                      // Never float. Floating brought the avatar and stats back
                      // on any upward flick — halfway down the grid the profile
                      // would drop in over the posts. Now only the top bar and
                      // the Map/Posts tabs stay put (both are `pinned`), and the
                      // profile block returns when the grid actually reaches the
                      // top. It also has to stay false on the map tab, where a
                      // floating header plus the locked scroll used to strand the
                      // header off-screen with no way back.
                      floatHeaderSlivers: false,
                      controller: _controller,
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverOverlapAbsorber(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                  context,
                                ),
                            sliver: MultiSliver(
                              children: [
                                UserProfileAppBar(
                                  sponsoredPost: props.sponsoredPost,
                                ),
                                if (!user.isAnonymous ||
                                    props.sponsoredPost != null) ...[
                                  UserProfileHeader(
                                    userId: widget.userId,
                                    sponsoredPost: props.sponsoredPost,
                                  ),
                                  // On a locked private account the Map/Posts
                                  // tabs are hidden entirely — they appear only
                                  // once the content is actually viewable.
                                  if (!tabsHidden)
                                    SliverPersistentHeader(
                                    // Always pinned: the tab bar has to stay on screen so
                                    // that a tab whose content fills the viewport (the
                                    // full-height travel map) can't scroll it away and
                                    // trap the user with no way back to the grid.
                                    pinned: true,
                                    delegate: _SliverAppBarDelegate(
                                      TabBar(
                                        indicatorSize: TabBarIndicatorSize.tab,
                                        padding: EdgeInsets.zero,
                                        labelPadding: EdgeInsets.zero,
                                        indicatorWeight: 1,
                                        tabs: [
                                          Tab(
                                            // Figma icon set; the other two tabs stay on
                                            // Material until their icons are exported.
                                            icon: Assets.icons.globusLined.svg(
                                              width: AppSize.iconSizeMedium,
                                              height: AppSize.iconSizeMedium,
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    AppColors.white,
                                                    BlendMode.srcIn,
                                                  ),
                                            ),
                                            iconMargin: EdgeInsets.zero,
                                          ),
                                          Tab(
                                            icon: Assets.icons.postsLined.svg(
                                              width: AppSize.iconSizeMedium,
                                              height: AppSize.iconSizeMedium,
                                              colorFilter:
                                                  const ColorFilter.mode(
                                                    AppColors.white,
                                                    BlendMode.srcIn,
                                                  ),
                                            ),
                                            iconMargin: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ];
                      },
                      body: tabsHidden
                          ? const _PrivateAccountNotice()
                          : TabBarView(
                              physics: onMap
                                  ? const NeverScrollableScrollPhysics()
                                  : null,
                              children: [
                                UserProfileTravelMap(userId: widget.userId),
                                PostsPage(
                                  key: _gridKey,
                                  sponsoredPost: props.sponsoredPost,
                                ),
                              ],
                            ),
                  );
                  }

                  final bloc = context.read<UserProfileBloc>();
                  final me = context.read<AppBloc>().state.user.id;
                  final isPrivate = context.select(
                    (UserProfileBloc b) => b.state.user.isPrivate,
                  );

                  // If the profile's owner has blocked me, the whole profile is
                  // private TO ME ONLY — even if it is public to everyone else.
                  return StreamBuilder<bool>(
                    stream: context.read<UserRepository>().isBlocked(
                      userId: widget.userId,
                      otherUserId: me,
                    ),
                    initialData: false,
                    builder: (context, blockSnap) {
                      if (blockSnap.data ?? false) return buildScaffold(true);
                      // Public account, or the owner's own profile: tabs on.
                      if (!isPrivate || bloc.isOwner) {
                        return buildScaffold(false);
                      }
                      // Private account viewed by someone else: locked until an
                      // accepted follower.
                      return StreamBuilder<bool>(
                        stream: bloc.followingStatus(),
                        initialData: false,
                        builder: (context, snapshot) =>
                            buildScaffold(!(snapshot.data ?? false)),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Flat page colour behind the tabs — the blurred glass strip predates the
    // design system.
    return ColoredBox(color: AppColors.background, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}

class _PrivateAccountNotice extends StatelessWidget {
  const _PrivateAccountNotice();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xlg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                    size: 44,
                  ),
                ),
                const Gap.v(AppSpacing.lg),
                Text(
                  context.l10n.privateAccountTitle,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: context.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap.v(AppSpacing.sm),
                Text(
                  context.l10n.privateAccountSubtitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PostsPage extends StatefulWidget {
  const PostsPage({this.sponsoredPost, super.key});

  final PostSponsoredBlock? sponsoredPost;

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<UserProfileBloc>();

    super.build(context);
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        SliverToBoxAdapter(
          child: StoryHighlightsRow(userId: bloc.userId, isOwner: bloc.isOwner),
        ),
        BetterStreamBuilder<List<Post>>(
          initialData: const <Post>[],
          // Raw posts (not blocks): passed as feedPosts so a tapped tile
          // scrolls through only this profile's posts — not everyone's.
          stream: bloc.userPostsRaw(),
          comparator: const ListEquality<Post>().equals,
          builder: (context, posts) {
            if (posts.isEmpty && widget.sponsoredPost == null) {
              return const EmptyPosts();
            }
            return SliverPadding(
              padding: EdgeInsets.zero,
              sliver: SliverGrid.builder(
                // Same tiles as the Trends grid: bigger, square-cornered,
                // hairline gaps.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 133 / 170,
                ),
                itemCount: widget.sponsoredPost != null ? 1 : posts.length,
                itemBuilder: (context, index) {
                  final block = widget.sponsoredPost ??
                      posts[index].toPostSmallBlock;
                  final multiMedia = block.media.length > 1;

                  return PostPopup(
                    block: block,
                    index: index,
                    // Keep the feed inside this profile; a sponsored tile keeps
                    // the default (newest) feed.
                    feedPosts: widget.sponsoredPost != null ? null : posts,
                    builder: (_) => PostSmall(
                      key: ValueKey(block.id),
                      pinned: false,
                      isReel: block.isReel,
                      multiMedia: multiMedia,
                      mediaUrl: block.firstMediaUrl ?? '',
                      imageThumbnailBuilder: (_, url) =>
                          PostSmallImage(post: block),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class PostSmallImage extends StatelessWidget {
  const PostSmallImage({required this.post, super.key});

  final PostBlock post;

  @override
  Widget build(BuildContext context) {
    return BlurHashImageThumbnail(
      id: post.id,
      // A third of a phone screen, so a fixed cap is plenty — and it keeps
      // every tile the same shape regardless of screen density.
      decodeWidth: 480,
      url: post.firstMediaUrl ?? '',
      blurHash: post.firstMedia?.blurHash,
    );
  }
}

class UserProfileMentionedPostsPage extends StatelessWidget {
  const UserProfileMentionedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        const EmptyPosts(icon: Icons.person_pin_outlined),
      ],
    );
  }
}

class UserProfileAppBar extends StatelessWidget {
  const UserProfileAppBar({this.sponsoredPost, super.key});

  final PostSponsoredBlock? sponsoredPost;

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select((UserProfileBloc bloc) => bloc.isOwner);
    final user$ = context.select((UserProfileBloc b) => b.state.user);
    final user = sponsoredPost == null
        ? user$
        : user$.isAnonymous
        ? sponsoredPost!.author.toUser
        : user$;

    final isRoot = ModalRoute.of(context)!.isFirst;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      sliver: SliverAppBar(
        // Opaque: the bar is pinned, so a transparent one let the grid scroll
        // visibly underneath the name and buttons.
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        centerTitle: true,
        // Design: the top bar (nickname, settings, edit) stays fixed while the
        // profile scrolls, so it never disappears.
        pinned: true,
        floating: false,
        leading: isOwner && isRoot
            ? Tappable.faded(
                onTap: () => context.pushNamed(AppRoutes.editProfile.name),
                child: const Icon(
                  Icons.edit_outlined,
                  size: AppSize.iconSizeMedium,
                ),
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                user.displayUsername,
                style: context.titleLarge?.copyWith(
                  fontWeight: AppFontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            // The one badge in the app: earned by invites, expires on its own.
            // This used to sit next to a second, server-persisted `referral_tier`
            // mark that never expired, so a profile could wear two different
            // checkmarks at once.
            TravelTierBadge(userId: user.id, size: 20),
          ],
        ),
        actions: [
          if (!isOwner)
            const UserProfileActions()
          else if (isRoot)
            const UserProfileSettingsButton(),
        ],
      ),
    );
  }
}

class UserProfileActions extends StatelessWidget {
  const UserProfileActions({super.key});

  Future<void> _showMenu(BuildContext context) async {
    final profileUser = context.read<UserProfileBloc>().state.user;
    final currentUserId = context.read<AppBloc>().state.user.id;
    final userRepo = context.read<UserRepository>();
    final link = 'https://treepnet.com/${profileUser.displayUsername}';
    final linkCopiedTitle = context.l10n.profileLinkCopiedText;
    final isSaved = await userRepo
        .isProfileSaved(userId: currentUserId, profileId: profileUser.id)
        .first;
    final isBlockedByMe = await userRepo
        .isBlocked(userId: currentUserId, otherUserId: profileUser.id)
        .first;
    if (!context.mounted) return;

    final option = await context.showListOptionsModal(
      options: [
        ModalOption(
          name: context.l10n.copyProfileLinkText,
          iconData: Icons.link_rounded,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: link));
            openSnackbar(
              SnackbarMessage.success(title: linkCopiedTitle),
              clearIfQueue: true,
            );
          },
        ),
        // Saved profiles land under Settings → Saved → Profile.
        ModalOption(
          name: isSaved ? context.l10n.unsaveText : context.l10n.saveText,
          iconData: isSaved ? Icons.bookmark : Icons.bookmark_border,
          onTap: () async {
            if (isSaved) {
              await userRepo.unsaveProfile(
                userId: currentUserId,
                profileId: profileUser.id,
              );
            } else {
              await userRepo.saveProfile(
                userId: currentUserId,
                profileId: profileUser.id,
              );
            }
            openSnackbar(
              SnackbarMessage.success(
                title: isSaved
                    ? context.l10n.removedFromSavedText
                    : context.l10n.savedText,
              ),
              clearIfQueue: true,
            );
          },
        ),
        if (isBlockedByMe)
          ModalOption(
            name: context.l10n.unblockText,
            iconData: Icons.block,
            actionTitle: context.l10n.unblockUserTitleText(
              profileUser.displayUsername,
            ),
            actionContent: context.l10n.unblockConfirmationText,
            actionYesText: context.l10n.unblockText,
            actionNoText: context.l10n.cancelText,
            onTap: () async {
              await context.read<UserRepository>().unblockUser(
                userId: currentUserId,
                blockedId: profileUser.id,
              );
              openSnackbar(
                SnackbarMessage.success(title: context.l10n.unblockedText),
                clearIfQueue: true,
              );
              if (context.mounted) Navigator.of(context).maybePop();
            },
          )
        else
          ModalOption(
            name: context.l10n.blockText,
            iconData: Icons.block,
            distractive: true,
            actionTitle: context.l10n.blockUserTitleText(
              profileUser.displayUsername,
            ),
            actionContent: context.l10n.blockConfirmationText,
            actionYesText: context.l10n.blockText,
            actionNoText: context.l10n.cancelText,
            onTap: () async {
              await context.read<UserRepository>().blockUser(
                userId: currentUserId,
                blockedId: profileUser.id,
              );
              openSnackbar(
                SnackbarMessage.success(title: context.l10n.blockedText),
                clearIfQueue: true,
              );
              if (context.mounted) Navigator.of(context).maybePop();
            },
          ),
      ],
    );
    if (option == null || !context.mounted) return;
    option.onTap(context);
  }

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: () => _showMenu(context),
      // Always the vertical kebab (⋮), matching every other 3-dot menu in the
      // app (chat header, post, story). `Icons.adaptive.more` rendered it
      // horizontal (⋯) on iOS, which looked sideways next to the rest.
      child: const Icon(Icons.more_vert, size: AppSize.iconSizeMedium),
    );
  }
}

class UserProfileSettingsButton extends StatelessWidget {
  const UserProfileSettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push<void>(MaterialPageRoute(builder: (_) => const SettingsPage())),
      child: Assets.icons.settingsLined.svg(
        width: AppSize.iconSizeMedium,
        height: AppSize.iconSizeMedium,
        colorFilter: const ColorFilter.mode(AppColors.white, BlendMode.srcIn),
      ),
    );
  }
}

class LogoutModalOption extends StatelessWidget {
  const LogoutModalOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Tappable.faded(
      onTap: () => context.confirmAction(
        fn: () {
          context.pop();
          context.read<AppBloc>().add(const AppLogoutRequested());
        },
        title: context.l10n.logOutText,
        content: context.l10n.logOutConfirmationText,
        noText: context.l10n.cancelText,
        yesText: context.l10n.logOutText,
      ),
      child: ListTile(
        title: Text(
          context.l10n.logOutText,
          style: context.bodyLarge?.apply(color: AppColors.red),
        ),
        leading: const Icon(Icons.logout, color: AppColors.red),
      ),
    );
  }
}

class UserProfileAddMediaButton extends StatelessWidget {
  const UserProfileAddMediaButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return Tappable.faded(
      onTap: () => context
          .showListOptionsModal(
            title: l10n.createText,
            options: createMediaModalOptions(
              context: context,
              reelLabel: l10n.reelText,
              postLabel: l10n.postText,
              storyLabel: l10n.storyText,
              enableStory: true,
              goTo: (route, {extra}) => context.pushNamed(route, extra: extra),
              onStoryCreated: (path) async {
                // Optional location: pin the story to a place (like a post).
                // Cancelling the picker leaves the story unpinned.
                final picked = await showLocationPicker(context);
                if (!context.mounted) return;
                context.read<CreateStoriesBloc>().add(
                  CreateStoriesStoryCreateRequested(
                    author: user,
                    contentType: StoryContentType.image,
                    filePath: path,
                    locationName: picked?.region.name,
                    locationLat: picked?.lat,
                    locationLng: picked?.lng,
                    onError: (_, _) {
                      toggleLoadingIndeterminate(enable: false);
                      openSnackbar(
                        SnackbarMessage.error(
                          title: l10n.somethingWentWrongText,
                          description: l10n.failedToCreateStoryText,
                        ),
                      );
                    },
                    onLoading: toggleLoadingIndeterminate,
                    onStoryCreated: () {
                      toggleLoadingIndeterminate(enable: false);
                      openSnackbar(
                        SnackbarMessage.success(
                          title: l10n.successfullyCreatedStoryText,
                        ),
                        clearIfQueue: true,
                      );
                    },
                  ),
                );
                context.pop();
              },
            ),
          )
          .then((option) {
            if (option == null) return;
            void onTap() => option.onTap(context);
            onTap.call();
          }),
      child: const Icon(Icons.add_box_outlined, size: AppSize.iconSizeMedium),
    );
  }
}

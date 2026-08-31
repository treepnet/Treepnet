import 'package:app_ui/app_ui.dart';
import 'package:treepnet/chat/chat.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/post/post.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

class SharePost extends StatelessWidget {
  const SharePost({
    required this.block,
    required this.scrollController,
    required this.draggableScrollController,
    super.key,
  });

  final PostBlock block;
  final ScrollController scrollController;
  final DraggableScrollableController draggableScrollController;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              UserProfileBloc(
                  userRepository: context.read<UserRepository>(),
                  postsRepository: context.read<PostsRepository>(),
                )
                ..add(const UserProfileFetchFollowersRequested())
                ..add(const UserProfileFetchFollowingsRequested()),
        ),
        BlocProvider(
          create: (context) => PostBloc(
            postId: block.id,
            postsRepository: context.read<PostsRepository>(),
            userRepository: context.read<UserRepository>(),
          ),
        ),
      ],
      child: SharePostView(
        block: block,
        scrollController: scrollController,
        draggableScrollController: draggableScrollController,
      ),
    );
  }
}

class SharePostView extends StatefulWidget {
  const SharePostView({
    required this.block,
    required this.scrollController,
    required this.draggableScrollController,
    super.key,
  });

  final PostBlock block;
  final ScrollController scrollController;
  final DraggableScrollableController draggableScrollController;

  @override
  State<SharePostView> createState() => _SharPostState();
}

class _SharPostState extends State<SharePostView> with SafeSetStateMixin {
  late TextEditingController _searchController;
  late FocusNode _focusNode;

  final _selectedUsers = ValueNotifier(<User>{});
  final _foundUsers = ValueNotifier(<User>{});

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode()..addListener(_focusListener);
  }

  void _focusListener() {
    if (_focusNode.hasFocus) {
      if (!widget.draggableScrollController.isAttached) return;
      if (widget.draggableScrollController.size == 1.0) return;
      widget.draggableScrollController.animateTo(
        1,
        duration: 250.ms,
        curve: Curves.ease,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode
      ..removeListener(_focusListener)
      ..dispose();
    _selectedUsers.dispose();
    _foundUsers.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(
      ClipboardData(text: 'https://treepnet.com/post/${widget.block.id}'),
    );
    openSnackbar(SnackbarMessage.success(title: context.l10n.linkCopiedText));
  }

  Future<void> _send() async {
    final selected = _selectedUsers.value.toList();
    if (selected.isEmpty) return;
    final shareRef = encodePostShare(widget.block.id);

    toggleLoadingIndeterminate();
    try {
      // Shared by reference: only the post id travels (a sentinel text), so no
      // media is duplicated. The chat thread renders it as a rich post card.
      for (final receiver in selected) {
        if (!mounted) return;
        await shareTextToUser(
          context,
          peerUuid: receiver.id,
          peerName: receiver.displayUsername,
          peerAvatarUrl: (receiver.avatarUrl?.isNotEmpty ?? false)
              ? receiver.avatarUrl
              : null,
          text: shareRef,
        );
      }
      if (mounted) context.pop();
      openSnackbar(
        SnackbarMessage.success(title: context.l10n.successfullySharedPostText),
      );
    } catch (error, stackTrace) {
      logE('Failed to share post.', error: error, stackTrace: stackTrace);
      openSnackbar(
        SnackbarMessage.error(title: context.l10n.failedToSharePostText),
      );
    } finally {
      toggleLoadingIndeterminate(enable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followers = context.select(
      (UserProfileBloc bloc) => bloc.state.followers,
    );
    final followings = context.select(
      (UserProfileBloc bloc) => bloc.state.followings,
    );

    final followersAndFollowings = {...followers, ...followings};
    // Flat dark page colour — `customReversedAdaptiveColor` swaps its
    // arguments and was returning white here.
    const backgroundColor = AppColors.background;

    return Theme(
      data: context.theme.copyWith(
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
        ),
      ),
      child: AppScaffold(
        releaseFocus: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            context.l10n.sharePostText,
            style: context.titleMedium?.copyWith(
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        // The actions live at the foot of the body, not in
        // `bottomNavigationBar`: inside the draggable sheet that slot is given
        // the full sheet height, which stretched the two buttons over the
        // whole screen and hid the recipient list.
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: UserSearchField(
                users: followersAndFollowings.toList(),
                searchController: _searchController,
                focusNode: _focusNode,
                onUsersFound: (users, query) {
                  final existedUsers = query.trim().isEmpty
                      ? <User>[]
                      : followersAndFollowings
                            .where(
                              (user) => user.displayUsername
                                  .toLowerCase()
                                  .trim()
                                  .contains(query.toLowerCase().trim()),
                            )
                            .toList();
                  if (existedUsers.isNotEmpty) {
                    final foundUsers = <User>[
                      ...existedUsers,
                      ...users.where(
                        (user) =>
                            !existedUsers.any((e) => e.id == user.id),
                      ),
                    ];
                    _foundUsers.value = {...foundUsers};
                  } else {
                    _foundUsers.value = {...users};
                  }
                },
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_foundUsers, _selectedUsers]),
                builder: (context, _) {
                  final list = _foundUsers.value.isNotEmpty
                      ? _foundUsers.value.toList()
                      : {
                          ..._selectedUsers.value,
                          ...followersAndFollowings,
                        }.toList();
                  return _ShareUserList(
                    users: list,
                    selectedUsers: _selectedUsers.value,
                    scrollController: widget.scrollController,
                    onToggle: (user) => safeSetState(() {
                      if (_selectedUsers.value.contains(user)) {
                        _selectedUsers.value.remove(user);
                      } else {
                        _selectedUsers.value.add(user);
                      }
                    }),
                  );
                },
              ),
            ),
            _ShareBottomBar(onCopyLink: _copyLink, onSend: _send),
          ],
        ),
      ),
    );
  }
}

/// Story version of the Share sheet — same UI as [SharePostView] (search,
/// recipient list, Copy link / Send), but it shares a story rather than a
/// post. There is no "shared story" message type, so Send delivers the story's
/// link as a direct message, and Copy link copies that same link.
class ShareStory extends StatelessWidget {
  const ShareStory({
    required this.storyId,
    required this.viewer,
    required this.scrollController,
    required this.draggableScrollController,
    super.key,
  });

  final String storyId;
  final User viewer;
  final ScrollController scrollController;
  final DraggableScrollableController draggableScrollController;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          UserProfileBloc(
              userRepository: context.read<UserRepository>(),
              postsRepository: context.read<PostsRepository>(),
            )
            ..add(const UserProfileFetchFollowersRequested())
            ..add(const UserProfileFetchFollowingsRequested()),
      child: ShareStoryView(
        storyId: storyId,
        viewer: viewer,
        scrollController: scrollController,
        draggableScrollController: draggableScrollController,
      ),
    );
  }
}

class ShareStoryView extends StatefulWidget {
  const ShareStoryView({
    required this.storyId,
    required this.viewer,
    required this.scrollController,
    required this.draggableScrollController,
    super.key,
  });

  final String storyId;
  final User viewer;
  final ScrollController scrollController;
  final DraggableScrollableController draggableScrollController;

  @override
  State<ShareStoryView> createState() => _ShareStoryState();
}

class _ShareStoryState extends State<ShareStoryView> with SafeSetStateMixin {
  late TextEditingController _searchController;
  late FocusNode _focusNode;

  final _selectedUsers = ValueNotifier(<User>{});
  final _foundUsers = ValueNotifier(<User>{});

  String get _storyLink => 'https://treepnet.com/story/${widget.storyId}';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _focusNode = FocusNode()..addListener(_focusListener);
  }

  void _focusListener() {
    if (_focusNode.hasFocus) {
      if (!widget.draggableScrollController.isAttached) return;
      if (widget.draggableScrollController.size == 1.0) return;
      widget.draggableScrollController.animateTo(
        1,
        duration: 250.ms,
        curve: Curves.ease,
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode
      ..removeListener(_focusListener)
      ..dispose();
    _selectedUsers.dispose();
    _foundUsers.dispose();
    super.dispose();
  }

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _storyLink));
    openSnackbar(SnackbarMessage.success(title: context.l10n.linkCopiedText));
  }

  Future<void> _send() async {
    final selected = _selectedUsers.value.toList();
    if (selected.isEmpty) return;
    final shareRef = encodeStoryShare(widget.storyId);

    toggleLoadingIndeterminate();
    try {
      // Shared by reference: only the story id travels (a sentinel text). The
      // chat thread renders it as a story card.
      for (final receiver in selected) {
        if (!mounted) return;
        await shareTextToUser(
          context,
          peerUuid: receiver.id,
          peerName: receiver.displayUsername,
          peerAvatarUrl: (receiver.avatarUrl?.isNotEmpty ?? false)
              ? receiver.avatarUrl
              : null,
          text: shareRef,
        );
      }
      if (mounted) context.pop();
      openSnackbar(
        SnackbarMessage.success(
          title: context.l10n.successfullySharedStoryText,
        ),
      );
    } catch (error, stackTrace) {
      logE('Failed to share story.', error: error, stackTrace: stackTrace);
      openSnackbar(
        SnackbarMessage.error(title: context.l10n.failedToShareStoryText),
      );
    } finally {
      toggleLoadingIndeterminate(enable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final followers = context.select(
      (UserProfileBloc bloc) => bloc.state.followers,
    );
    final followings = context.select(
      (UserProfileBloc bloc) => bloc.state.followings,
    );

    final followersAndFollowings = {...followers, ...followings};
    const backgroundColor = AppColors.background;

    return Theme(
      data: context.theme.copyWith(
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: backgroundColor,
          surfaceTintColor: backgroundColor,
        ),
      ),
      child: AppScaffold(
        releaseFocus: true,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            context.l10n.sharePostText,
            style: context.titleMedium?.copyWith(
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: UserSearchField(
                users: followersAndFollowings.toList(),
                searchController: _searchController,
                focusNode: _focusNode,
                onUsersFound: (users, query) {
                  final existedUsers = query.trim().isEmpty
                      ? <User>[]
                      : followersAndFollowings
                            .where(
                              (user) => user.displayUsername
                                  .toLowerCase()
                                  .trim()
                                  .contains(query.toLowerCase().trim()),
                            )
                            .toList();
                  if (existedUsers.isNotEmpty) {
                    final foundUsers = <User>[
                      ...existedUsers,
                      ...users.where(
                        (user) => !existedUsers.any((e) => e.id == user.id),
                      ),
                    ];
                    _foundUsers.value = {...foundUsers};
                  } else {
                    _foundUsers.value = {...users};
                  }
                },
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: Listenable.merge([_foundUsers, _selectedUsers]),
                builder: (context, _) {
                  final list = _foundUsers.value.isNotEmpty
                      ? _foundUsers.value.toList()
                      : {
                          ..._selectedUsers.value,
                          ...followersAndFollowings,
                        }.toList();
                  return _ShareUserList(
                    users: list,
                    selectedUsers: _selectedUsers.value,
                    scrollController: widget.scrollController,
                    onToggle: (user) => safeSetState(() {
                      if (_selectedUsers.value.contains(user)) {
                        _selectedUsers.value.remove(user);
                      } else {
                        _selectedUsers.value.add(user);
                      }
                    }),
                  );
                },
              ),
            ),
            _ShareBottomBar(onCopyLink: _copyLink, onSend: _send),
          ],
        ),
      ),
    );
  }
}

/// The two white actions at the foot of the Share sheet.
class _ShareBottomBar extends StatelessWidget {
  const _ShareBottomBar({required this.onCopyLink, required this.onSend});

  final VoidCallback onCopyLink;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        // Fixed height so the pills keep their shape whatever the sheet does.
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              Expanded(
                child: _WhiteButton(
                  label: context.l10n.copyLinkText,
                  onTap: onCopyLink,
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: _WhiteButton(
                  label: context.l10n.sendText,
                  onTap: onSend,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable.scaled(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: context.labelLarge?.copyWith(
              color: AppColors.black,
              fontWeight: AppFontWeight.semiBold,
            ),
          ),
        ),
      ),
    );
  }
}

/// The recipient list: avatar + name + verified badge, with a radio circle
/// on the right (filled white-with-check when selected).
class _ShareUserList extends StatelessWidget {
  const _ShareUserList({
    required this.users,
    required this.selectedUsers,
    required this.scrollController,
    required this.onToggle,
  });

  final List<User> users;
  final Set<User> selectedUsers;
  final ScrollController scrollController;
  final ValueSetter<User> onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: users.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: AppColors.borderOutline.withValues(alpha: 0.5),
      ),
      itemBuilder: (context, index) {
        final user = users[index];
        final selected = selectedUsers.contains(user);
        return Tappable.faded(
          onTap: () => onToggle(user),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                UserProfileAvatar(
                  avatarUrl: user.avatarUrl,
                  isLarge: false,
                  radius: 22,
                  enableBorder: false,
                ),
                const Gap.h(AppSpacing.md),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.displayUsername,
                          style: context.bodyLarge?.copyWith(
                            fontWeight: AppFontWeight.semiBold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Gap.h(AppSpacing.xs),
                      // Was hardcoded, so every recipient looked verified.
                      TravelTierBadge(userId: user.id),
                    ],
                  ),
                ),
                _RadioCircle(selected: selected),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RadioCircle extends StatelessWidget {
  const _RadioCircle({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.white : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.white : AppColors.grey,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 16, color: AppColors.black)
          : null,
    );
  }
}

class UserSearchField extends StatefulWidget {
  const UserSearchField({
    required this.users,
    required this.searchController,
    required this.focusNode,
    required this.onUsersFound,
    super.key,
  });

  final List<User> users;
  final TextEditingController searchController;
  final FocusNode focusNode;
  final void Function(List<User> users, String query) onUsersFound;

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  late Debouncer _debouncer;

  final _inactiveIconColor = AppColors.grey;
  final _activeIconColor = AppColors.white;

  late final _iconColor = ValueNotifier(_inactiveIconColor);

  @override
  void initState() {
    super.initState();
    _debouncer = Debouncer();

    widget.focusNode.addListener(_focusListener);
  }

  void _focusListener() {
    if (widget.focusNode.hasFocus) {
      _iconColor.value = _activeIconColor;
    } else {
      _iconColor.value = _inactiveIconColor;
    }
  }

  void _noUsersFound() => widget.onUsersFound.call([], '');

  @override
  void dispose() {
    widget.focusNode.removeListener(_focusListener);
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchRepository = context.read<SearchRepository>();
    final searchController = widget.searchController;

    return AnimatedBuilder(
      animation: Listenable.merge([_iconColor, searchController]),
      builder: (context, _) {
        return AppTextField(
          textController: searchController,
          focusNode: widget.focusNode,
          onChanged: (query) => _debouncer.run(() async {
            if (query.trim().isEmpty) {
              _noUsersFound();
              return;
            }
            final users = await searchRepository.searchUsers(query: query);
            widget.onUsersFound.call(users, query);
          }),
          filled: true,
          hintText: context.l10n.searchText,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          prefixIcon: Icon(Icons.search, color: _iconColor.value),
          suffixIcon: searchController.text.trim().isEmpty
              ? null
              : Tappable.faded(
                  onTap: () {
                    searchController.clear();
                    _noUsersFound();
                  },
                  child: Icon(Icons.clear, color: _iconColor.value),
                ),
          border: outlinedBorder(borderRadius: 10),
        );
      },
    );
  }
}

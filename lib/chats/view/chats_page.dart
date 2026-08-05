// ignore_for_file: deprecated_member_use

import 'package:app_ui/app_ui.dart';
import 'package:chats_repository/chats_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/app/routes/app_routes.dart';
import 'package:treepnet/chats/bloc/chats_bloc.dart';
import 'package:treepnet/chats/chat/chat.dart';
import 'package:treepnet/chats/widgets/chat_inbox_tile.dart';
import 'package:treepnet/home/home.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);
    return BlocProvider(
      create: (context) =>
          ChatsBloc(chatsRepository: context.read<ChatsRepository>())
            ..add(ChatsSubscriptionRequested(userId: user.id)),
      child: const ChatsView(),
    );
  }
}

class ChatsView extends StatefulWidget {
  const ChatsView({super.key});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> {
  // 0 = Type (people you can start a chat with), 1 = existing Chats.
  int _tab = 1;

  final _searchController = TextEditingController();
  final _pageController = PageController(initialPage: 1);
  String _query = '';

  /// Tab tap → animate the swipeable page to it (page swipe updates [_tab]).
  void _goToTab(int t) {
    if (!_pageController.hasClients) {
      setState(() => _tab = t);
      return;
    }
    _pageController.animateToPage(
      t,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        // Tapping anywhere off the search field dismisses the keyboard and
        // drops focus.
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                ChatsTopTabs(
                  currentTab: _tab,
                  onChanged: _goToTab,
                ),
                ChatsSearchField(
                  controller: _searchController,
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) => setState(() => _tab = page),
                    children: [
                      _TypeListView(query: _query, userId: user.id),
                      RefreshIndicator.adaptive(
                        onRefresh: () async {
                          context.read<ChatsBloc>().add(
                            ChatsSubscriptionRequested(userId: user.id),
                          );
                          // Hold the spinner until the chat list re-emits.
                          await context
                              .read<ChatsRepository>()
                              .chatsOf(userId: user.id)
                              .first;
                        },
                        child: CustomScrollView(
                          // Let a short list still trigger the refresh pull.
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            ChatsListView(
                              query: _query,
                              onStartChat: () => _goToTab(0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The `Type` / `Chats` header from the design.
class ChatsTopTabs extends StatelessWidget {
  const ChatsTopTabs({
    required this.currentTab,
    required this.onChanged,
    super.key,
  });

  final int currentTab;
  final ValueSetter<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Tab(
            label: context.l10n.chatsTypeTabText,
            isActive: currentTab == 0,
            onTap: () => onChanged(0),
          ),
          const Gap.h(AppSpacing.xxlg),
          _Tab(
            label: context.l10n.chatsTabText,
            isActive: currentTab == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: context.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: AppFontWeight.semiBold,
              color: isActive ? AppColors.white : AppColors.textSecondary,
            ),
          ),
          const Gap.v(AppSpacing.xs),
          Container(
            height: 2,
            width: isActive ? 48 : 0,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The `Type` tab: people you follow / suggested accounts you haven't chatted
/// with yet. Tapping one starts a conversation (it then shows under Chats).
class _TypeListView extends StatefulWidget {
  const _TypeListView({
    required this.userId,
    this.query = '',
  });

  final String userId;

  /// Lower-cased search text; empty shows everyone.
  final String query;

  @override
  State<_TypeListView> createState() => _TypeListViewState();
}

class _TypeListViewState extends State<_TypeListView> {
  Future<List<User>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  /// Open the conversation without listing it under Chats yet — a person only
  /// moves to Chats once at least one message has been exchanged.
  Future<void> _openChat(User user) async {
    final chatId = await context.read<ChatsRepository>().createChat(
      userId: widget.userId,
      participantId: user.id,
    );
    if (!mounted) return;
    await context.pushNamed(
      AppRoutes.chat.name,
      pathParameters: {'chat_id': chatId},
      extra: ChatProps(chat: ChatInbox(id: chatId, participant: user)),
    );
  }

  Future<List<User>> _load() async {
    final repo = context.read<UserRepository>();
    final followings = await repo.getFollowings(userId: widget.userId);
    final suggested = await repo.suggestedUsers();
    final seen = <String>{};
    final all = <User>[];
    for (final u in [...followings, ...suggested]) {
      if (u.id == widget.userId) continue;
      if (seen.add(u.id)) all.add(u);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    // Only people with an actual conversation (a message exchanged) are hidden
    // from Type; a freshly-opened-but-empty chat keeps them here.
    final existingIds = context.select(
      (ChatsBloc bloc) => bloc.state.chats
          .where((c) => c.lastMessageAt != null)
          .map((c) => c.participant.id)
          .toSet(),
    );
    return FutureBuilder<List<User>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final users = snapshot.data!
            .where((u) => !existingIds.contains(u.id))
            .where(
              (u) =>
                  widget.query.isEmpty ||
                  u.displayUsername.toLowerCase().contains(widget.query) ||
                  u.displayFullName.toLowerCase().contains(widget.query),
            )
            .toList();
        if (users.isEmpty) {
          return Center(
            child: Text(
              context.l10n.noOneToMessageText,
              style: context.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: users.length,
          separatorBuilder: (_, _) => Divider(
            height: 1,
            color: AppColors.borderOutline.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserProfileAvatar(
                avatarUrl: user.avatarUrl,
                isLarge: false,
                radius: 22,
                enableBorder: false,
              ),
              // Only the username — no full name, per the design.
              title: Text(
                user.displayUsername,
                style: context.bodyLarge?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
              onTap: () => _openChat(user),
            );
          },
        );
      },
    );
  }
}

/// Rounded search box above the chat list.
class ChatsSearchField extends StatelessWidget {
  const ChatsSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.inputSpace,
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
        child: Row(
          children: [
            Assets.icons.searchLined.svg(
              width: AppSize.iconSizeSmall,
              height: AppSize.iconSizeSmall,
              colorFilter: const ColorFilter.mode(
                AppColors.white,
                BlendMode.srcIn,
              ),
            ),
            const Gap.h(AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: context.bodyMedium?.copyWith(color: AppColors.white),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: context.l10n.searchText,
                  hintStyle: context.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatsAppBar extends StatelessWidget {
  const ChatsAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AppBloc bloc) => bloc.state.user);

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => HomeProvider().animateToPage(1),
        icon: Icon(Icons.adaptive.arrow_back, size: AppSize.iconSizeMedium),
      ),
      centerTitle: false,
      pinned: true,
      title: Text(
        user.displayUsername,
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: AppFontWeight.bold,
          color: context.colorScheme.onSurface,
        ),
      ),
      actions: [
        Tappable.faded(
          onTap: () async {
            void createChat(String participantId) =>
                context.read<ChatsBloc>().add(
                  ChatsCreateChatRequested(
                    userId: user.id,
                    participantId: participantId,
                  ),
                );

            final participantId =
                await context.push('/timeline/search', extra: true) as String?;
            if (participantId == null) return;
            createChat(participantId);
          },
          child: const Icon(Icons.add, size: AppSize.iconSizeMedium),
        ),
      ],
    );
  }
}

class ChatsListView extends StatelessWidget {
  const ChatsListView({this.query = '', this.onStartChat, super.key});

  /// Lower-cased search text; empty shows everything.
  final String query;

  /// Tapping the empty-state button (jumps to the Type tab).
  final VoidCallback? onStartChat;

  @override
  Widget build(BuildContext context) {
    // Hide conversations with no messages yet — they only appear once someone
    // has actually said something.
    final all = context.select(
      (ChatsBloc bloc) =>
          bloc.state.chats.where((c) => c.lastMessageAt != null).toList(),
    );
    final chats = query.isEmpty
        ? all
        : all
              .where(
                (c) =>
                    c.participant.displayUsername.toLowerCase().contains(
                      query,
                    ) ||
                    c.participant.displayFullName.toLowerCase().contains(query),
              )
              .toList();
    if (chats.isEmpty) return ChatsEmpty(onStartChat: onStartChat);
    return SliverList.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        return ChatInboxTile(chat: chat);
      },
    );
  }
}

class ChatsEmpty extends StatelessWidget {
  const ChatsEmpty({this.onStartChat, super.key});

  final VoidCallback? onStartChat;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.flip(
                flipX: true,
                child: Assets.icons.chatCircle.svg(
                  height: 86,
                  width: 86,
                  colorFilter: ColorFilter.mode(
                    context.adaptiveColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              gapH8,
              Text(
                context.l10n.noChatsText,
                style: context.textTheme.headlineLarge?.copyWith(
                  fontWeight: AppFontWeight.semiBold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              gapH8,
              // "Start a chat" now jumps to the Type tab (pick someone), not a
              // separate search page. Grey #414141 fill, white text.
              Tappable.scaled(
                onTap: onStartChat,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xlg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF414141),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.startChatText,
                    style: context.labelLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

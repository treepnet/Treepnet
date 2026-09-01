import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart';
import 'package:treepnet/stories/widgets/user_stories_avatar.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/chat_theme.dart';
import 'package:treepnet/chat/open_chat.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

/// The chat inbox — two tabs matching the app design:
///   • Type  ("Написать") — people to start a new chat with (follows +
///     suggestions), searchable.
///   • Chats ("Чаты")     — existing conversations, searchable.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  final _pageController = PageController(initialPage: 1);
  final _searchController = TextEditingController();
  int _tab = 1; // 0 = Type, 1 = Chats
  String _query = '';
  Future<void>? _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _start();
  }

  Future<void> _start() async {
    final me = context.read<AppBloc>().state.user;
    final repo = context.read<UserRepository>();
    await ChatSession.instance.ensureStarted(
      myUuid: me.id,
      myName: await currentChatName(repo, me),
      myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToTab(int tab) {
    setState(() => _tab = tab);
    _pageController.animateToPage(
      tab,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select((AppBloc bloc) => bloc.state.user.id);

    return Scaffold(
      backgroundColor: ChatTheme.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopTabs(currentTab: _tab, onChanged: _goToTab),
              _SearchField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              Expanded(
                child: FutureBuilder<void>(
                  future: _bootstrap,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: ChatTheme.accent,
                        ),
                      );
                    }
                    return PageView(
                      controller: _pageController,
                      onPageChanged: (page) => setState(() => _tab = page),
                      children: [
                        _TypeList(query: _query, userId: userId),
                        _ChatsList(
                          query: _query,
                          onStartChat: () => _goToTab(0),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Написать" / "Чаты" header tabs.
class _TopTabs extends StatelessWidget {
  const _TopTabs({required this.currentTab, required this.onChanged});

  final int currentTab;
  final ValueSetter<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
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
  Widget build(BuildContext context) => Tappable(
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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

/// Rounded search box, matching the app's other search inputs.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
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

/// "Type" tab: follows + suggestions you haven't chatted with yet. Tapping one
/// starts a conversation.
class _TypeList extends StatefulWidget {
  const _TypeList({required this.userId, required this.query});

  final String userId;
  final String query;

  @override
  State<_TypeList> createState() => _TypeListState();
}

class _TypeListState extends State<_TypeList> {
  Future<List<User>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<User>> _load() async {
    final repo = context.read<UserRepository>();
    final followings = await repo.getFollowings(userId: widget.userId);
    final suggested = await repo.suggestedUsers();
    final seen = <String>{};
    final all = <User>[];
    for (final u in [...followings, ...suggested]) {
      if (u.id == widget.userId || u.isAnonymous) continue;
      if (seen.add(u.id)) all.add(u);
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    // Hide only people we've actually exchanged a message with — a person
    // opened-but-not-messaged stays here until something is written.
    final existing = ChatSession.instance.isStarted
        ? ChatSession.instance.listTransport.messagedPeerUuids
        : const <String>{};

    return FutureBuilder<List<User>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ChatTheme.accent,
              ),
            ),
          );
        }
        final users = snapshot.data!
            .where((u) => !existing.contains(u.id))
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
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: AppColors.borderOutline.withValues(alpha: 0.4),
          ),
          itemBuilder: (context, index) {
            final user = users[index];
            return _PersonRow(
              avatarUrl: user.avatarUrl,
              author: user,
              title: user.displayUsername,
              onTap: () => openChat(
                context,
                peerUuid: user.id,
                peerName: user.displayUsername,
                peerAvatarUrl: user.hasAvatar ? user.avatarUrl : null,
              ),
            );
          },
        );
      },
    );
  }
}

/// "Chats" tab: existing conversations from the shared list transport, filtered
/// by the search query and kept live via the transport's events.
class _ChatsList extends StatefulWidget {
  const _ChatsList({required this.query, this.onStartChat});

  final String query;

  /// Jumps to the "Type" tab from the empty-state button.
  final VoidCallback? onStartChat;

  @override
  State<_ChatsList> createState() => _ChatsListState();
}

class _ChatsListState extends State<_ChatsList> {
  final Map<String, ChatConversation> _map = {};
  StreamSubscription<ChatListEvent>? _sub;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  Future<void> _bind() async {
    await _sub?.cancel();
    _sub = null;
    if (!ChatSession.instance.isStarted) {
      setState(() {
        _loading = false;
        _error = 'not-started';
      });
      return;
    }
    final transport = ChatSession.instance.listTransport;
    _sub = transport.events.listen(_onEvent);
    try {
      await transport.connect();
      final page = await transport.loadConversations(page: 1, size: 50);
      for (final c in page.conversations) {
        _map[c.id] = c;
      }
    } catch (e) {
      _error = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onEvent(ChatListEvent event) {
    if (!mounted) return;
    switch (event) {
      case ChatConversationUpserted(:final conversation):
        setState(() => _map[conversation.id] = conversation);
      case ChatConversationRemoved(:final conversationId):
        setState(() => _map.remove(conversationId));
      case ChatPeerPresenceChanged(:final peerId, :final isOnline, :final lastSeen):
        final match = _map.values
            .where((c) => c.peer.id == peerId)
            .toList(growable: false);
        if (match.isEmpty) return;
        setState(() {
          for (final c in match) {
            _map[c.id] = c.copyWith(
              peer: c.peer.copyWith(isOnline: isOnline, lastSeen: lastSeen),
            );
          }
        });
      case ChatListConnectionChanged():
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: ChatTheme.accent),
      );
    }

    if (_error != null && _map.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.noChatsText,
              style: context.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Gap.v(AppSpacing.sm),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _bind();
              },
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      );
    }

    final conversations =
        _map.values
            // Only conversations with an actual message — a freshly opened but
            // empty one stays out of Chats until something is written.
            .where((c) => c.lastMessage.isNotEmpty)
            .where(
              (c) =>
                  widget.query.isEmpty ||
                  c.peer.name.toLowerCase().contains(widget.query),
            )
            .toList()
          ..sort((a, b) {
            final at = a.lastMessageAt;
            final bt = b.lastMessageAt;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

    if (conversations.isEmpty) {
      return _ChatsEmpty(onStartChat: widget.onStartChat);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: AppColors.borderOutline.withValues(alpha: 0.4),
      ),
      itemBuilder: (context, index) =>
          _ConversationTile(conversation: conversations[index]),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ChatConversation conversation;

  String _preview() {
    if (conversation.lastMessage.isNotEmpty) return conversation.lastMessage;
    return switch (conversation.lastMessageKind) {
      ChatMessageKind.photo => '📷 Rasm',
      ChatMessageKind.video => '🎬 Video',
      ChatMessageKind.voice => '🎤 Ovozli xabar',
      ChatMessageKind.file => '📎 Fayl',
      ChatMessageKind.text => '',
    };
  }

  String _time(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) {
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}';
  }

  /// Long-press → confirm → delete the whole conversation (both sides).
  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final couldNotDelete = context.l10n.couldNotDeleteChatText;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ChatTheme.bubble,
        title: Text(
          dialogContext.l10n.deleteChatText,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          dialogContext.l10n.chatDeleteConfirmationText,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              dialogContext.l10n.deleteText,
              style: const TextStyle(color: Color(0xffE5484D)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !ChatSession.instance.isStarted) return;
    try {
      await ChatSession.instance.listTransport.deleteConversation(
        conversation.id,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(couldNotDelete)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final preview = _preview();

    // Resolve the peer's app uuid so the avatar can show their story ring
    // (the ChatUser only carries the backend id).
    final peerUuid = ChatSession.instance.isStarted
        ? ChatSession.instance.listTransport.peerUuidOf(conversation.id)
        : null;
    final author = (peerUuid != null && peerUuid.isNotEmpty)
        ? User(
            id: peerUuid,
            username: conversation.peer.name,
            avatarUrl: conversation.peer.avatarUrl,
          )
        : null;

    return _PersonRow(
      avatarUrl: conversation.peer.avatarUrl,
      author: author,
      title: conversation.peer.name,
      subtitle: preview.isEmpty ? null : preview,
      onTap: () => openConversationScreen(
        context,
        conversationId: conversation.id,
        peer: conversation.peer,
      ),
      onLongPress: () => _confirmDelete(context),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (unread > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$unread',
                style: context.labelSmall?.copyWith(
                  color: AppColors.black,
                  fontWeight: AppFontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox(height: 22),
          const Gap.v(AppSpacing.xs),
          Text(
            _time(conversation.lastMessageAt),
            style: context.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The empty "Chats" state — a large chat glyph, a title and a button that
/// jumps to the "Type" tab (matching the old chat design).
class _ChatsEmpty extends StatelessWidget {
  const _ChatsEmpty({this.onStartChat});

  final VoidCallback? onStartChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.flip(
              flipX: true,
              child: Assets.icons.chatCircle.svg(
                height: 86,
                width: 86,
                colorFilter: const ColorFilter.mode(
                  AppColors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const Gap.v(AppSpacing.sm),
            Text(
              context.l10n.noChatsText,
              style: context.headlineLarge?.copyWith(
                fontWeight: AppFontWeight.semiBold,
                color: AppColors.white,
              ),
            ),
            if (onStartChat != null) ...[
              const Gap.v(AppSpacing.md),
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
          ],
        ),
      ),
    );
  }
}

/// A single inbox row (person or conversation), laid out with an explicit
/// [Row] instead of [ListTile].
///
/// [ListTile] measures its own intrinsic width and asserts when a `leading`
/// widget ends up as wide as the tile — which is exactly what happened inside
/// the swipeable [PageView] on some Android devices, blanking the whole page.
/// A plain Row with a fixed-size avatar and an [Expanded] text column is
/// immune to that and always lays out against the width it is given.
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.avatarUrl,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.onLongPress,
    this.author,
  });

  final String? avatarUrl;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onLongPress;

  /// When set, the avatar shows the app-wide story ring for this user. The
  /// avatar itself stays non-interactive (wrapped in [IgnorePointer]) so the
  /// row's own tap — opening the chat — still wins.
  final User? author;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      onLongPress: onLongPress,
      backgroundColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: author != null
                  ? UserStoriesAvatar(
                      author: author!,
                      isLarge: false,
                      radius: 20,
                      withAdaptiveBorder: false,
                      // Only the WHITE (unseen) ring in chat — no grey "seen"
                      // ring.
                      enableInactiveBorder: false,
                      // Tapping the avatar opens an unseen story; with no
                      // (unseen) story it falls through to opening the chat,
                      // same as tapping the rest of the row.
                      onAvatarTap: (_) => onTap(),
                    )
                  : UserProfileAvatar(
                      avatarUrl: avatarUrl,
                      isLarge: false,
                      radius: 22,
                      enableBorder: false,
                    ),
            ),
            const Gap.h(AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.bodyLarge?.copyWith(
                      fontWeight: AppFontWeight.semiBold,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const Gap.v(AppSpacing.xxs),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const Gap.h(AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

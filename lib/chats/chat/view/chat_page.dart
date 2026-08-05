// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chats_repository/chats_repository.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/chats/chat/chat.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:inview_notifier_list/inview_notifier_list.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({required this.chatId, required this.chat, super.key});

  final ChatInbox chat;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatBloc(
        chatId: chatId,
        chatsRepository: context.read<ChatsRepository>(),
        currentUserId: context.read<AppBloc>().state.user.id,
      )
        ..add(const ChatMessagesFetchRequested())
        // Opening the chat marks everything in it read, clearing the badge.
        ..add(ChatMarkReadRequested(context.read<AppBloc>().state.user.id)),
      child: ChatView(chat: chat),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({required this.chat, super.key});

  final ChatInbox chat;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late MessageInputController _messageInputController;
  late FocusNode _focusNode;

  late ItemScrollController _itemScrollController;
  late ItemPositionsListener _itemPositionsListener;
  late ScrollOffsetController _scrollOffsetController;
  late ScrollOffsetListener _scrollOffsetListener;

  Future<void> _reply(Message message) async {
    _messageInputController.setReplyingMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _edit(Message message) async {
    _messageInputController.setEditingMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _delete(Message message) {
    context.read<ChatBloc>().add(ChatMessageDeleteRequested(message.id));
  }

  @override
  void initState() {
    super.initState();
    _messageInputController = MessageInputController();
    _focusNode = FocusNode();

    _itemScrollController = ItemScrollController();
    _itemPositionsListener = ItemPositionsListener.create();
    _scrollOffsetController = ScrollOffsetController();
    _scrollOffsetListener = ScrollOffsetListener.create();
  }

  @override
  void dispose() {
    _messageInputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppBloc>().state.user;
    bool isMine(Message message) {
      return message.sender?.id == user.id;
    }

    return TreepNetAmbientBackground(
      child: AppScaffold(
        backgroundColor: Colors.transparent,
        appBar: ChatAppBar(
          participant: widget.chat.participant,
          chatId: widget.chat.id,
        ),
        releaseFocus: true,
        body: BlocListener<ChatBloc, ChatState>(
          // Warn (once per new failure) that a send failed, with a Retry that
          // re-sends the still-visible bubble — its text is never lost.
          listenWhen: (previous, current) =>
              current.status == ChatStatus.failure &&
              current.failedIds.isNotEmpty &&
              current.failedIds != previous.failedIds,
          listener: (context, state) {
            final bloc = context.read<ChatBloc>();
            final failed = state.messages
                .where((m) => state.failedIds.contains(m.id))
                .toList();
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(context.l10n.messageNotSentText),
                  action: SnackBarAction(
                    label: context.l10n.retryText,
                    onPressed: () {
                      for (final m in failed) {
                        bloc.add(
                          ChatSendMessageRequested(
                            message: m,
                            sender: user,
                            receiver: widget.chat.participant,
                          ),
                        );
                      }
                    },
                  ),
                ),
              );
          },
          child: Column(
            children: [
              Expanded(
                child: BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    final messages = state.messages;
                    // Empty thread: show a loading / error / "no messages"
                    // placeholder instead of a permanently blank screen.
                    if (messages.isEmpty) {
                      return _ChatEmptyState(
                        status: state.status,
                        onRetry: () => context
                            .read<ChatBloc>()
                            .add(const ChatMessagesFetchRequested()),
                      );
                    }
                    return ChatMessagesListView(
                      messages: messages,
                      messageSettings: MessageSettings.create(
                        onReplyTap: (message) => _reply.call(
                          message.copyWith(
                            replyMessageUsername: isMine(message)
                                ? user.username
                                : widget.chat.participant.username,
                          ),
                        ),
                        onEditTap: _edit,
                        onDeleteTap: _delete,
                      ),
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      scrollOffsetController: _scrollOffsetController,
                      scrollOffsetListener: _scrollOffsetListener,
                    );
                  },
                ),
              ),
              // Block gating: no messaging in EITHER direction. If I blocked
              // them the bar offers unblock; if they blocked me it just says
              // messaging is unavailable.
              StreamBuilder<bool>(
                stream: context.read<UserRepository>().isBlocked(
                  userId: user.id,
                  otherUserId: widget.chat.participant.id,
                ),
                initialData: false,
                builder: (context, iBlockedSnap) {
                  final iBlocked = iBlockedSnap.data ?? false;
                  return StreamBuilder<bool>(
                    stream: context.read<UserRepository>().isBlocked(
                      userId: widget.chat.participant.id,
                      otherUserId: user.id,
                    ),
                    initialData: false,
                    builder: (context, blockedMeSnap) {
                      final blockedMe = blockedMeSnap.data ?? false;
                      if (iBlocked || blockedMe) {
                        return _BlockedComposerBar(iBlocked: iBlocked);
                      }
                      return ChatMessageTextField(
                        focusNode: _focusNode,
                        itemScrollController: _itemScrollController,
                        messageInputController: _messageInputController,
                        chat: widget.chat,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatMessagesListView extends StatefulWidget {
  const ChatMessagesListView({
    required this.messages,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.scrollOffsetController,
    required this.scrollOffsetListener,
    required this.messageSettings,
    super.key,
  });

  final List<Message> messages;
  final MessageSettings messageSettings;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final ScrollOffsetController scrollOffsetController;
  final ScrollOffsetListener scrollOffsetListener;

  @override
  State<ChatMessagesListView> createState() => _ChatMessagesListViewState();
}

class _ChatMessagesListViewState extends State<ChatMessagesListView>
    with SingleTickerProviderStateMixin {
  late ValueNotifier<bool> _showScrollToBottom;
  late ValueNotifier<bool> _isNextPageLoading;

  late final Animation<double> _animation = CurvedAnimation(
    curve: Curves.easeOutQuad,
    parent: _controller,
  );
  late final AnimationController _controller = AnimationController(vsync: this);

  MessageSettings get settings => widget.messageSettings;
  List<Message> get messages => widget.messages;

  final _autoScrollController = AutoScrollController();

  /// Id of the newest message last time we built — used to detect a freshly
  /// added message so the list can follow it to the bottom.
  String? _lastTopId;

  @override
  void initState() {
    super.initState();
    _showScrollToBottom = ValueNotifier(false);
    _isNextPageLoading = ValueNotifier(false);
    _lastTopId = widget.messages.firstOrNull?.id;
    // The list is reverse:true, so offset 0 is the bottom (newest). Drive the
    // scroll-to-bottom FAB off how far the user has scrolled up from there.
    _autoScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_autoScrollController.hasClients) return;
    final show = _autoScrollController.offset > 240;
    if (show != _showScrollToBottom.value) _showScrollToBottom.value = show;
  }

  void _scrollToBottom() {
    if (!_autoScrollController.hasClients) return;
    _autoScrollController.animateTo(
      0,
      duration: 200.ms,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant ChatMessagesListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final topId = widget.messages.firstOrNull?.id;
    // A new newest message appeared. Follow it down when it's mine (I just
    // sent it) or when the reader is already near the bottom; if they've
    // scrolled up to read history, leave them there — the FAB handles the rest.
    if (topId != null &&
        topId != _lastTopId &&
        widget.messages.length > oldWidget.messages.length) {
      final myId = context.read<AppBloc>().state.user.id;
      final mine = widget.messages.first.sender?.id == myId;
      final nearBottom =
          !_autoScrollController.hasClients ||
          _autoScrollController.offset < 300;
      if (mine || nearBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
    _lastTopId = topId;
  }

  Future<void> _scrollToMessage(
    String repliedMessageId,
    List<Message> messages, {
    bool withHighlight = true,
  }) async {
    final index = messages.indexWhere((m) => m.id == repliedMessageId);
    if (index == -1) return;
    await _autoScrollController.scrollToIndex(
      index,
      preferPosition: AutoScrollPosition.middle,
    );
    if (withHighlight) {
      await _autoScrollController.highlight(index, highlightDuration: 1500.ms);
    }
  }

  @override
  void dispose() {
    _autoScrollController.removeListener(_handleScroll);
    _autoScrollController.dispose();
    _showScrollToBottom.dispose();
    _isNextPageLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select((ChatBloc bloc) => bloc.state.hasMore);

    return Stack(
      children: [
        const ChatBackground(),
        Column(
          children: [
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return InViewNotifierCustomScrollView(
                    onListEndReached: () async {
                      if (!hasMore) return;
                      if (_isNextPageLoading.value) return;

                      Future<void> loadNextPage() async => context
                          .read<ChatBloc>()
                          .add(const ChatMessagesFetchRequested());

                      _controller
                        ..duration = Duration.zero
                        // ignore: unawaited_futures
                        ..forward();

                      _isNextPageLoading.value = true;

                      await loadNextPage().whenComplete(() {
                        if (mounted) {
                          _controller
                            ..duration = const Duration(milliseconds: 300)
                            ..reverse();

                          _isNextPageLoading.value = false;
                        }
                      });
                    },
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _autoScrollController,
                    initialInViewIds: [messages.lastOrNull?.id ?? ''],
                    isInViewPortCondition: (deltaTop, deltaBottom, vpHeight) {
                      return deltaTop < (0.5 * vpHeight) + 80.0 &&
                          deltaBottom > (0.5 * vpHeight) - 80.0;
                    },
                    reverse: true,
                    slivers: [
                      SliverList.separated(
                        itemCount: messages.length,
                        // NOTE: `findChildIndexCallback` was removed. It mapped
                        // message-id keys to cached indices, but when a message
                        // was inserted (an incoming message shifts every index)
                        // the cached map went stale and flutter asserted
                        // `child == _child`, replacing the whole thread with a
                        // red error box. Flutter matches the ValueKey(id) items
                        // correctly on its own; the list is small enough that
                        // the linear match costs nothing.
                        itemBuilder: (context, index) {
                          final isFirst = index == 0;
                          final isLast = index + 1 == messages.length;
                          final message = messages[index];
                          final nextMessage = isLast
                              ? null
                              : messages[index + 1];
                          final previousMessage = isFirst
                              ? null
                              : messages[index - 1];
                          // Null-safe: a message with no sender (e.g.
                          // Message.empty from a deleted reply) must not crash
                          // the whole thread with a `!` on null.
                          final isNextUserSame =
                              nextMessage != null &&
                              message.sender?.id == nextMessage.sender?.id;
                          final isPreviousUserSame =
                              previousMessage != null &&
                              message.sender?.id == previousMessage.sender?.id;

                          bool checkTimeDifference(
                            DateTime date1,
                            DateTime date2,
                          ) => !Jiffy.parseFromDateTime(date1).isSame(
                            Jiffy.parseFromDateTime(date2),
                            unit: Unit.minute,
                          );

                          var hasTimeDifferenceWithNext = false;
                          if (nextMessage != null) {
                            hasTimeDifferenceWithNext = checkTimeDifference(
                              message.createdAt,
                              nextMessage.createdAt,
                            );
                          }

                          var hasTimeDifferenceWithPrevious = false;
                          if (previousMessage != null) {
                            hasTimeDifferenceWithPrevious = checkTimeDifference(
                              message.createdAt,
                              previousMessage.createdAt,
                            );
                          }

                          final messageWidget = AutoScrollTag(
                            index: index,
                            key: ValueKey('scroll-${message.id}'),
                            controller: _autoScrollController,
                            highlightColor: AppColors.blue.withValues(
                              alpha: .2,
                            ),
                            child: MessageBubble(
                              onEditTap: settings.onEditTap,
                              onReplyTap: settings.onReplyTap,
                              onDeleteTap: settings.onDeleteTap,
                              onRepliedMessageTap: (repliedMessageId) =>
                                  _scrollToMessage(repliedMessageId, messages),
                              message: message,
                              onMessageTap:
                                  (
                                    details,
                                    messageId, {
                                    required isMine,
                                    required hasSharedPost,
                                  }) => settings.onMessageTap(
                                    details,
                                    messageId,
                                    context: context,
                                    isMine: isMine,
                                    hasSharedPost: hasSharedPost,
                                  ),
                              borderRadius: ({required isMine}) =>
                                  BorderRadius.only(
                                    topLeft: isMine
                                        ? const Radius.circular(22)
                                        : (isNextUserSame &&
                                              !hasTimeDifferenceWithNext)
                                        ? const Radius.circular(4)
                                        : const Radius.circular(22),
                                    topRight: !isMine
                                        ? const Radius.circular(22)
                                        : (isNextUserSame &&
                                              !hasTimeDifferenceWithNext)
                                        ? const Radius.circular(4)
                                        : const Radius.circular(22),
                                    bottomLeft: isMine
                                        ? const Radius.circular(22)
                                        : (isPreviousUserSame &&
                                              !hasTimeDifferenceWithPrevious)
                                        ? const Radius.circular(4)
                                        : Radius.zero,
                                    bottomRight: !isMine
                                        ? const Radius.circular(22)
                                        : (isPreviousUserSame &&
                                              !hasTimeDifferenceWithPrevious)
                                        ? const Radius.circular(4)
                                        : Radius.zero,
                                  ),
                            ),
                          );

                          final padding = isFirst
                              ? const EdgeInsets.only(bottom: AppSpacing.md)
                              : isLast
                              ? const EdgeInsets.only(top: AppSpacing.md)
                              : null;

                          return SwipeableMessage(
                            key: ValueKey(message.id),
                            onSwiped: (_) => settings.onReplyTap.call(message),
                            child: Padding(
                              padding: padding ?? EdgeInsets.zero,
                              child: messageWidget,
                            ),
                          );
                        },
                        separatorBuilder: (context, index) {
                          final isLast = messages.length == index + 1;
                          final message = messages[index];
                          final nextMessage = isLast
                              ? null
                              : messages[index + 1];
                          if (message.createdAt.day !=
                              nextMessage?.createdAt.day) {
                            return MessageDateTimeSeparator(
                              date: message.createdAt,
                            );
                          }
                          final isNextUserSame =
                              nextMessage != null &&
                              message.sender?.id == nextMessage.sender?.id;

                          var hasTimeDifference = false;

                          if (nextMessage != null) {
                            hasTimeDifference =
                                !Jiffy.parseFromDateTime(
                                  message.createdAt,
                                ).isSame(
                                  Jiffy.parseFromDateTime(
                                    nextMessage.createdAt,
                                  ),
                                  unit: Unit.minute,
                                );
                          }

                          if (isNextUserSame && !hasTimeDifference) {
                            return const Gap.v(AppSpacing.xxs);
                          }

                          return const Gap.v(AppSpacing.sm);
                        },
                      ),
                      SliverPadding(
                        padding: EdgeInsets.only(
                          top:
                              16 +
                              (context.isMobile
                                  ? MediaQuery.paddingOf(context).top
                                  : 0),
                        ),
                        sliver: SliverToBoxAdapter(
                          child: SizeTransition(
                            axisAlignment: 1,
                            sizeFactor: _animation,
                            child: Center(
                              child: Container(
                                alignment: Alignment.center,
                                height: 38,
                                width: 38,
                                child: const SizedBox(
                                  height: 26,
                                  width: 26,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _showScrollToBottom,
          child: ScrollToBottomButton(
            scrollToBottom: () {
              // Scroll the ACTUAL list controller (reverse:true → offset 0 is
              // the newest message). The old `itemScrollController` was never
              // attached, so this button did nothing.
              _scrollToBottom();
              _showScrollToBottom.value = false;
            },
          ),
          builder: (context, show, child) {
            return Positioned(
              right: 0,
              bottom: 0,
              child: AnimatedScale(
                scale: show ? 1 : 0,
                curve: Curves.bounceInOut,
                duration: 150.ms,
                child: child,
              ),
            );
          },
        ),

        /// Unfortunately, chat floating date separator is not working anymore
        /// because I've swapped `ScrollablePositionList` to
        /// `SliverList.separated` in favor of `findChildIndexCallback` which
        /// is not available with `ScrollablePositionList` and it significantly
        /// boosts performance. However, it doesn't mean that we can't scroll
        /// to a specific message. We can still scroll to a specific message
        /// by using [scroll_to_index] package. It adds `AutoScrollController`
        /// and we can use it to scroll to a specific message and also
        /// has built in feature for highlighting the message.
        // Positioned(
        //   top: 0,
        //   left: 0,
        //   right: 0,
        //   child: ChatFloatingDateSeparator(
        //     reverse: false,
        //     messages: messages,
        //     itemCount: messages.length,
        //     itemPositionsListener: ValueNotifier([]),
        //   ),
        // ),
      ],
    );
  }
}

class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({required this.participant, required this.chatId, super.key});

  final User participant;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leadingWidth: 36,
      title: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(participant.displayUsername),
        subtitle: _ChatHeaderStatus(
          participantId: participant.id,
          conversationId: chatId,
        ),
        leading: UserStoriesAvatar(
          resizeHeight: 156,
          author: participant,
          enableInactiveBorder: false,
          withAdaptiveBorder: false,
          radius: 22,
        ),
      ),
      // Design: an overflow menu with Block user / Delete.
      actions: [
        _ChatOverflowMenu(participant: participant, chatId: chatId),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({required this.scrollToBottom, super.key});

  final VoidCallback scrollToBottom;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      shape: const CircleBorder(),
      onPressed: scrollToBottom,
      backgroundColor: context.customReversedAdaptiveColor(
        light: AppColors.white,
        dark: AppColors.emphasizeDarkGrey,
      ),
      child: const Icon(Icons.arrow_downward_rounded),
    );
  }
}

/// The header's ⋮ menu: block this person, or delete the conversation.
class _ChatOverflowMenu extends StatelessWidget {
  const _ChatOverflowMenu({required this.participant, required this.chatId});

  final User participant;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    final me = context.read<AppBloc>().state.user.id;
    return StreamBuilder<bool>(
      stream: context.read<UserRepository>().isBlocked(
        userId: me,
        otherUserId: participant.id,
      ),
      initialData: false,
      builder: (context, snapshot) {
        final blocked = snapshot.data ?? false;
        return PopupMenuButton<_ChatMenuAction>(
          icon: const Icon(Icons.more_vert),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          onSelected: (action) {
            final users = context.read<UserRepository>();
            final chats = context.read<ChatsRepository>();
            final navigator = Navigator.of(context);

            switch (action) {
              case _ChatMenuAction.block:
                // One flow for both directions, always confirmed. Blocking and
                // unblocking here write the same blocked_users rows the profile
                // menu and Settings → Blocked users use.
                context.confirmAction(
                  title: blocked
                      ? context.l10n.unblockAuthorText
                      : context.l10n.blockAuthorText,
                  content: blocked
                      ? context.l10n.unblockUserTitleText(
                          participant.displayUsername,
                        )
                      : context.l10n.blockAuthorConfirmationText,
                  yesText: blocked
                      ? context.l10n.unblockText
                      : context.l10n.blockText,
                  noText: context.l10n.cancelText,
                  yesTextStyle: TextStyle(
                    color: blocked ? null : AppColors.red,
                  ),
                  fn: () => blocked
                      ? users.unblockUser(userId: me, blockedId: participant.id)
                      : users.blockUser(userId: me, blockedId: participant.id),
                );
              case _ChatMenuAction.delete:
                context.confirmAction(
                  title: context.l10n.deleteChatText,
                  content: context.l10n.chatDeleteConfirmationText,
                  yesText: context.l10n.deleteText,
                  noText: context.l10n.cancelText,
                  yesTextStyle: const TextStyle(color: AppColors.red),
                  fn: () async {
                    await chats.deleteChat(chatId: chatId, userId: me);
                    navigator.maybePop();
                  },
                );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ChatMenuAction.block,
              child: Text(
                blocked
                    ? context.l10n.unblockAuthorText
                    : context.l10n.blockAuthorText,
              ),
            ),
            PopupMenuItem(
              value: _ChatMenuAction.delete,
              child: Text(
                context.l10n.deleteText,
                style: const TextStyle(color: AppColors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _ChatMenuAction { block, delete }

/// The chat header's status line: "typing…" while the participant types,
/// otherwise "online" when their heartbeat is fresh, else "last seen …".
/// Re-evaluates on a timer so it ages correctly even without new data.
class _ChatHeaderStatus extends StatefulWidget {
  const _ChatHeaderStatus({
    required this.participantId,
    required this.conversationId,
  });

  final String participantId;
  final String conversationId;

  @override
  State<_ChatHeaderStatus> createState() => _ChatHeaderStatusState();
}

class _ChatHeaderStatusState extends State<_ChatHeaderStatus> {
  DateTime? _lastSeen;
  DateTime? _typingAt;
  StreamSubscription<DateTime?>? _lastSeenSub;
  StreamSubscription<DateTime?>? _typingSub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    final me = context.read<AppBloc>().state.user.id;
    _lastSeenSub = context
        .read<UserRepository>()
        .lastSeenOf(userId: widget.participantId)
        .listen((v) {
          if (mounted) setState(() => _lastSeen = v);
        });
    _typingSub = context
        .read<ChatsRepository>()
        .typingUpdatedAtOf(
          conversationId: widget.conversationId,
          excludeUserId: me,
        )
        .listen((v) {
          if (mounted) setState(() => _typingAt = v);
        });
    _ticker = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _lastSeenSub?.cancel();
    _typingSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  /// The stored value is a local wall-clock time; after a sync round-trip it can
  /// come back labelled UTC. Rebuild it from its calendar fields as a local
  /// time so the elapsed-time maths isn't skewed by the timezone offset.
  DateTime _asLocalWallClock(DateTime d) =>
      DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);

  Duration? _elapsed(DateTime? d) =>
      d == null ? null : DateTime.now().difference(_asLocalWallClock(d));

  @override
  Widget build(BuildContext context) {
    final typing = _elapsed(_typingAt);
    if (typing != null && typing.inSeconds < 6) {
      return Text(context.l10n.typingText);
    }
    final seen = _elapsed(_lastSeen);
    if (seen == null) return const SizedBox.shrink();
    final String text;
    if (seen.inSeconds < 90) {
      text = context.l10n.onlineText;
    } else if (seen.inMinutes < 60) {
      text = context.l10n.lastSeenMinutesText(seen.inMinutes);
    } else if (seen.inHours < 24) {
      text = context.l10n.lastSeenHoursText(seen.inHours);
    } else if (seen.inDays < 7) {
      text = context.l10n.lastSeenDaysText(seen.inDays);
    } else {
      text = context.l10n.lastSeenAWhileText;
    }
    return Text(text);
  }
}

/// Shown in place of the message list when a thread has no messages yet:
/// a loading spinner, a load error with retry, or a friendly empty state.
class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.status, required this.onRetry});

  final ChatStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatStatus.initial:
      case ChatStatus.loading:
        return const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        );
      case ChatStatus.failure:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.white,
                size: 44,
              ),
              const Gap.v(AppSpacing.md),
              Text(
                "Couldn't load messages",
                style: context.bodyLarge?.copyWith(color: AppColors.white),
              ),
              const Gap.v(AppSpacing.sm),
              TextButton(onPressed: onRetry, child: Text(context.l10n.retryText)),
            ],
          ),
        );
      case ChatStatus.success:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.white,
                size: 44,
              ),
              const Gap.v(AppSpacing.md),
              Text(
                context.l10n.noMessagesYetText,
                style: context.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: AppFontWeight.semiBold,
                ),
              ),
              const Gap.v(AppSpacing.xs),
              Text(
                context.l10n.sayHiText,
                style: context.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// Replaces the composer when messaging is blocked. [iBlocked] distinguishes
/// "I blocked them" (I can unblock) from "they blocked me" (nothing I can do).
class _BlockedComposerBar extends StatelessWidget {
  const _BlockedComposerBar({required this.iBlocked});

  final bool iBlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Text(
        iBlocked
            ? context.l10n.blockedThisUserText
            : context.l10n.cantMessageUserText,
        textAlign: TextAlign.center,
        style: context.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

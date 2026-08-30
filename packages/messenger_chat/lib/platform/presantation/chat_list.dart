part of messenger_chat;

/// Suhbatlar ro'yxati - real vaqtda yangilanadi.
///
/// Ilova [ChatListTransport] beradi, vidjet esa yuklash, tartiblash va
/// hodisalarni qo'llashni o'z zimmasiga oladi:
///
/// * yangi xabar kelganda suhbat yuqoriga ko'tariladi;
/// * o'qilmaganlar soni yangilanadi;
/// * suhbatdosh onlayn holati o'zgaradi.
///
/// ```dart
/// MessengerChatList(
///   transport: myListTransport,
///   style: const ChatListStyle(),
///   onConversationTap: (c) => Navigator.push(...),
/// )
/// ```
class MessengerChatList extends StatefulWidget {
  const MessengerChatList({
    required this.transport,
    required this.onConversationTap,
    this.style = const ChatListStyle(),
    this.pageSize = 30,
    this.emptyBuilder,
    this.lang = ChatLanguage.uzbek,
    super.key,
  });

  final ChatListTransport transport;

  /// Suhbat tanlanganda chaqiriladi - odatda chat ekraniga o'tiladi.
  final void Function(ChatConversation conversation) onConversationTap;

  final ChatListStyle style;

  final int pageSize;

  /// Ro'yxat bo'sh bo'lganda ko'rsatiladigan vidjet.
  final WidgetBuilder? emptyBuilder;

  /// Interfeys tili.
  ///
  /// Ro'yxat suhbat ekranidan oldin ochilishi mumkin, shuning uchun u tilni
  /// o'zi sozlaydi - aks holda "Фото", "Голосовое сообщение" kabi matnlar
  /// standart tilda qolib ketadi.
  final ChatLanguage lang;

  @override
  State<MessengerChatList> createState() => _MessengerChatListState();
}

class _MessengerChatListState extends State<MessengerChatList> {
  final List<ChatConversation> _conversations = [];
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<ChatListEvent>? _subscription;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _ChatLocalizations.instance.initialize(widget.lang);
    _scrollController.addListener(_onScroll);
    _subscription = widget.transport.events.listen(_onEvent);
    unawaited(_start());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await widget.transport.connect();
    } catch (e) {
      // Socket ulanmasa ham ro'yxatni ko'rsatishga harakat qilamiz.
      _ChatLogger.failure('Chat list transport ulanmadi: $e');
    }
    await _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (!refresh && (_isLoadingMore || !_hasMore)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
        _failure = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = refresh ? 1 : _page + 1;
      final result = await widget.transport.loadConversations(
        page: page,
        size: widget.pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _conversations
            ..clear()
            ..addAll(result.conversations);
        } else {
          // Dublikatlarni oldini olamiz - server bir suhbatni ikki sahifada
          // qaytarishi mumkin.
          final existing = _conversations.map((c) => c.id).toSet();
          _conversations.addAll(
            result.conversations.where((c) => !existing.contains(c.id)),
          );
        }
        _page = page;
        _hasMore = result.hasMore;
        _sort();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _failure = e);
      _ChatLogger.failure('Suhbatlarni yuklashda xato: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      unawaited(_load());
    }
  }

  void _onEvent(ChatListEvent event) {
    if (!mounted) return;

    switch (event) {
      case ChatConversationUpserted(:final conversation):
        setState(() {
          final index = _conversations.indexWhere(
            (c) => c.id == conversation.id,
          );
          if (index >= 0) {
            _conversations[index] = conversation;
          } else {
            _conversations.add(conversation);
          }
          _sort();
        });

      case ChatConversationRemoved(:final conversationId):
        setState(() => _conversations.removeWhere((c) => c.id == conversationId));

      case ChatPeerPresenceChanged(:final peerId, :final isOnline, :final lastSeen):
        setState(() {
          for (var i = 0; i < _conversations.length; i++) {
            final item = _conversations[i];
            if (item.peer.id != peerId) continue;
            _conversations[i] = item.copyWith(
              peer: item.peer.copyWith(isOnline: isOnline, lastSeen: lastSeen),
            );
          }
        });

      case ChatListConnectionChanged():
        // Ro'yxat uchun ulanish holati alohida ko'rsatilmaydi.
        break;
    }
  }

  /// Qadalganlar tepada, keyin oxirgi xabar vaqti bo'yicha yangidan eskiga.
  void _sort() {
    _conversations.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final aTime = a.lastMessageAt;
      final bTime = b.lastMessageAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      if (_failure != null) {
        return _ChatListMessage(
          text: _AppTexts.somethingWentWrong,
          onRetry: () => _load(refresh: true),
          style: widget.style,
        );
      }
      return widget.emptyBuilder?.call(context) ??
          _ChatListMessage(text: _AppTexts.noMessages, style: widget.style);
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _conversations.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => widget.style.showDividers
            ? Divider(
                height: 1,
                indent: 84,
                color: widget.style.dividerColor,
              )
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index >= _conversations.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final conversation = _conversations[index];
          return _ConversationTile(
            conversation: conversation,
            style: widget.style,
            onTap: () => widget.onConversationTap(conversation),
          );
        },
      ),
    );
  }
}

class _ChatListMessage extends StatelessWidget {
  const _ChatListMessage({
    required this.text,
    required this.style,
    this.onRetry,
  });

  final String text;
  final ChatListStyle style;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: style.previewTextStyle),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: Text(_AppTexts.retry)),
        ],
      ],
    ),
  );
}

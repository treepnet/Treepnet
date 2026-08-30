part of messenger_chat;

/// Chat ro'yxatidagi bitta qator: avatar, ism, oxirgi xabar, vaqt va
/// o'qilmaganlar soni.
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.style,
    required this.onTap,
  });

  final ChatConversation conversation;
  final ChatListStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Avatar(peer: conversation.peer, style: style),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.peer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.titleTextStyle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_time, style: style.timeTextStyle),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // O'zimiz yuborgan oxirgi xabar yonida o'qildi belgisi.
                    if (conversation.lastMessageIsMine &&
                        conversation.lastMessage.isNotEmpty) ...[
                      Icon(
                        conversation.lastMessageIsRead
                            ? ChatIcons.doubleCheck
                            : ChatIcons.check,
                        size: 16,
                        color: conversation.lastMessageIsRead
                            ? style.readIconColor
                            : style.unreadIconColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        _preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style.previewTextStyle,
                      ),
                    ),
                    if (conversation.unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      _UnreadBadge(
                        count: conversation.unreadCount,
                        style: style,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// Media xabarlar uchun matn o'rniga turini yozamiz.
  String get _preview {
    if (conversation.lastMessage.isNotEmpty) return conversation.lastMessage;
    return switch (conversation.lastMessageKind) {
      ChatMessageKind.photo => _AppTexts.photo,
      ChatMessageKind.video => _AppTexts.video,
      ChatMessageKind.voice => _AppTexts.voiceMessage,
      ChatMessageKind.file => _AppTexts.file,
      ChatMessageKind.text => '',
    };
  }

  /// Bugungi xabar uchun soat, aks holda sana.
  String get _time {
    final date = conversation.lastMessageAt;
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return isToday
        ? DateFormat.Hm().format(date)
        : DateFormat('dd.MM.yy').format(date);
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.peer, required this.style});

  final ChatUser peer;
  final ChatListStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 56,
    height: 56,
    child: Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: style.avatarBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: (peer.avatarUrl?.isNotEmpty ?? false)
              ? CachedNetworkImage(
                  imageUrl: peer.avatarUrl!,
                  fit: BoxFit.cover,
                  width: 56,
                  height: 56,
                  errorWidget: (_, __, ___) => _initials,
                  placeholder: (_, __) => _initials,
                )
              : _initials,
        ),
        if (peer.isOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: style.onlineColor,
                shape: BoxShape.circle,
                border: Border.all(color: style.backgroundColor, width: 2),
              ),
            ),
          ),
      ],
    ),
  );

  Widget get _initials => Center(
    child: Text(peer.initials, style: style.avatarTextStyle),
  );
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.style});

  final int count;
  final ChatListStyle style;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 22),
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: style.unreadBadgeColor,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      count > 99 ? '99+' : '$count',
      style: style.unreadBadgeTextStyle,
    ),
  );
}

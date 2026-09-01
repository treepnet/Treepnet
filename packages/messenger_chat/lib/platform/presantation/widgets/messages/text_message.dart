part of messenger_chat;

class _TextMessage extends StatefulWidget {
  const _TextMessage({
    required this.message,
    required this.showSenderName,
    required this.messageStyle,
  });

  final bool showSenderName;
  final _MessageModel message;
  final ChatMessageStyle messageStyle;

  @override
  State<_TextMessage> createState() => _TextMessageState();
}

class _TextMessageState extends State<_TextMessage> {
  Metadata? _metadata;
  bool _isFetching = false;
  String? _detectedUrl;

  @override
  void initState() {
    super.initState();
    _checkAndFetch();
  }

  @override
  void didUpdateWidget(covariant _TextMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message.content.content != oldWidget.message.content.content) {
      _checkAndFetch();
    }
  }

  void _checkAndFetch() {
    final content = widget.message.content.content;
    final urlRegex = RegExp(
      r'(?:(?:https?|ftp):\/\/)?[\w/\-?=%.]+\.[\w/\-?=%.]+',
    );
    final match = urlRegex.firstMatch(content);
    final url = match?.group(0);

    if (url != null && url != _detectedUrl) {
      _detectedUrl = url;
      _fetchMetadata(url.startsWith('http') ? url : 'https://$url');
    } else if (url == null) {
      _detectedUrl = null;
      _metadata = null;
    }
  }

  Future<void> _fetchMetadata(String url) async {
    if (_isFetching) return;
    setState(() => _isFetching = true);

    try {
      final metadata = await AnyLinkPreview.getMetadata(
        link: url,
        cache: const Duration(days: 7),
      );
      if (mounted) {
        setState(() {
          _metadata = metadata;
          _isFetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetching = false);
      }
    }
  }

  Future<void> _launchUrl() async {
    if (_detectedUrl == null) return;
    final url = _detectedUrl!.startsWith('http')
        ? _detectedUrl!
        : 'https://$_detectedUrl';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _ChatLogger.print('Xatolik: havolani ochib bo\'lmadi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.message.isFromPeer;
    final style = widget.messageStyle;

    // App-provided shared-content card (e.g. a shared post/story sent as a
    // sentinel-encoded text message). When the app returns a widget for this
    // content, render it instead of the plain text bubble.
    final shared = _ChatRuntime.instance.sharedMessageBuilder?.call(
      context,
      widget.message.content.content,
    );
    if (shared != null) return shared;

    if (widget.message.isDeleted) {
      final base = isAdmin
          ? style.adminMessageTextStyle
          : style.clientMessageTextStyle;
      return Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isAdmin
              ? style.adminMessageBackgroundColor
              : style.clientMessageBackgroundColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: Colors.white54),
            const SizedBox(width: 6),
            Text(
              _AppTexts.messageDeleted,
              style: base.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      );
    }

    final timeStyle = isAdmin
        ? style.adminMessageTimeTextStyle
        : style.clientMessageTimeTextStyle;
    final content = widget.message.content.content;

    // Meta line (time · "tahrirlangan" · sent/read tick) placed on its OWN row
    // BELOW the text, right-aligned. It used to overlap the last text line
    // (a Positioned overlay whose reserved space didn't account for the
    // "tahrirlangan" label), which made an edited message unreadable.
    final metaRow = Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (widget.message.isEdited) ...[
          Text(
            _AppTexts.edited,
            style: timeStyle.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(width: 6),
        ],
        Text(widget.message.time, style: timeStyle),
        if (!isAdmin) ...[
          const SizedBox(width: 6),
          Icon(
            switch (widget.message.status) {
              (MessageStatus.sending) => ChatIcons.clock,
              (MessageStatus.delivered) => ChatIcons.check,
              (MessageStatus.seen) => ChatIcons.doubleCheck,
              (MessageStatus.error) => ChatIcons.alertCircle,
            },
            size: 16,
            color: switch (widget.message.status.isError) {
              (true) => Colors.redAccent,
              (false) => style.readIconColor,
            },
          ),
        ],
      ],
    );

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.85,
      ),
      decoration: BoxDecoration(
        color: isAdmin
            ? style.adminMessageBackgroundColor
            : style.clientMessageBackgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // IntrinsicWidth so the bubble is as wide as its widest line (the text,
        // or the meta row when the text is shorter than it) — the meta then
        // right-aligns cleanly under the text instead of stretching the bubble.
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdmin &&
                  widget.showSenderName &&
                  widget.message.senderName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    widget.message.senderName,
                    style: style.adminMessageTextStyle.copyWith(
                      color: style.adminAuthorTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (widget.message.replyTo != null)
                _QuotedReply(
                  reply: widget.message.replyTo!,
                  isAdmin: isAdmin,
                  style: style,
                ),
              Text(
                content,
                maxLines: 1000,
                style: isAdmin
                    ? style.adminMessageTextStyle
                    : style.clientMessageTextStyle,
              ),
              if (_metadata != null &&
                  (_metadata!.title != null || _metadata!.desc != null)) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _launchUrl,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isAdmin ? Colors.white : Colors.blueAccent)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? Colors.white.withOpacity(0.7)
                                : Colors.blueAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_metadata!.title != null)
                                Text(
                                  _metadata!.title!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isAdmin
                                        ? Colors.white
                                        : Colors.blueAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              if (_metadata!.desc != null)
                                Text(
                                  _metadata!.desc!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isAdmin
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 3),
              metaRow,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bubble ichidagi iqtibos - bu xabar qaysi xabarga javob ekanini ko'rsatadi.
class _QuotedReply extends StatelessWidget {
  const _QuotedReply({
    required this.reply,
    required this.isAdmin,
    required this.style,
  });

  final ChatReplyInfo reply;
  final bool isAdmin;
  final ChatMessageStyle style;

  @override
  Widget build(BuildContext context) {
    final base = isAdmin
        ? style.adminMessageTextStyle
        : style.clientMessageTextStyle;
    final author = reply.senderId == _ChatRuntime.instance.me.id
        ? _ChatRuntime.instance.me.name
        : (_ChatRuntime.instance.peer?.name ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: Colors.white70, width: 2.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (author.isNotEmpty)
              Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            Text(
              // Shared post/story sentinels → a friendly label, via the app
              // hook (was showing the raw `treepnet:share:...` text).
              _ChatRuntime.instance.sharedReplyPreview?.call(reply.content) ??
                  reply.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(
                fontSize: 12,
                color: (base.color ?? Colors.white).withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

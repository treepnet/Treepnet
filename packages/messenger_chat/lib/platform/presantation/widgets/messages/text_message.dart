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

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: isAdmin
            ? style.adminMessageBackgroundColor
            : style.clientMessageBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Visibility(
                  visible: isAdmin &&
                      widget.showSenderName &&
                      widget.message.senderName.isNotEmpty,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      widget.message.senderName,
                      style: style.adminMessageTextStyle.copyWith(
                        color: style.adminAuthorTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const timeWidgetWidth = 70.0;
                    final content = widget.message.content.content;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(
                                  0.0,
                                  constraints.maxWidth - timeWidgetWidth,
                                ),
                              ),
                              child: Text(
                                content,
                                maxLines: 1000,
                                style: isAdmin
                                    ? style.adminMessageTextStyle
                                    : style.clientMessageTextStyle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.message.time,
                                  style: style.clientMessageTimeTextStyle
                                      .copyWith(color: Colors.transparent),
                                ),
                                if (!isAdmin) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.done_rounded,
                                    size: 16,
                                    color: Colors.transparent,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        if (_metadata != null &&
                            (_metadata!.title != null ||
                                _metadata!.desc != null)) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _launchUrl,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    (isAdmin ? Colors.white : Colors.blueAccent)
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        if (_metadata!.image != null &&
                                            _metadata!.image!.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: _metadata!.image!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const SizedBox.shrink(),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const SizedBox.shrink(),
                                              ),
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
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message.time,

                  style: isAdmin
                      ? style.adminMessageTimeTextStyle
                      : style.clientMessageTimeTextStyle,
                ),
                if (!isAdmin) ...[
                  const SizedBox(width: 8),
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
            ),
          ),
        ],
      ),
    );
  }
}

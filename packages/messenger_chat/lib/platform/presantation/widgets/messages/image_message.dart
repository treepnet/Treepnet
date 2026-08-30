part of messenger_chat;

class _ImageMessage extends StatefulWidget {
  const _ImageMessage({
    required this.message,
    required this.messageStyle,
    required this.showSenderName,
  });

  final _MessageModel message;
  final ChatMessageStyle messageStyle;
  final bool showSenderName;

  @override
  State<_ImageMessage> createState() => _ImageMessageState();
}

class _ImageMessageState extends State<_ImageMessage>
    with AutomaticKeepAliveClientMixin {
  BorderRadius get borderRadius => BorderRadius.circular(16);

  BorderRadius get borderRadiusBottom => const BorderRadius.only(
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: (widget.message.isFromPeer
            ? widget.messageStyle.adminMessageBackgroundColor
            : widget.messageStyle.clientMessageBackgroundColor),
        border: Border.all(
          strokeAlign: BorderSide.strokeAlignOutside,
          color: widget.message.isFromPeer
              ? widget.messageStyle.adminMessageBackgroundColor
              : widget.messageStyle.clientMessageBackgroundColor,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              settings: RouteSettings(
                name: '/imageViewScreen',
                arguments:
                    '${widget.message.content.content}',
              ),
              builder: (context) => _ImageViewScreen(
                image:
                    '${widget.message.content.content}',
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: widget.message.isFromPeer
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color:
                    (widget.message.isFromPeer
                            ? widget.messageStyle.adminMessageBackgroundColor
                            : widget.messageStyle.clientMessageBackgroundColor)
                        .withAlpha((255 * 0.3).round()),
                border: Border.all(
                  strokeAlign: BorderSide.strokeAlignOutside,
                  color: widget.message.isFromPeer
                      ? widget.messageStyle.adminMessageBackgroundColor
                      : widget.messageStyle.clientMessageBackgroundColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Visibility(
                    visible:
                        widget.message.isFromPeer && widget.showSenderName,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: widget.message.width,
                        color: widget.message.isFromPeer
                            ? widget.messageStyle.adminMessageBackgroundColor
                            : widget.messageStyle.clientMessageBackgroundColor,
                        padding: const EdgeInsets.only(
                          top: 10.0,
                          left: 10,
                          bottom: 4,
                        ),
                        child: Text(
                          widget.message.senderName,
                          style: widget.messageStyle.adminMessageTextStyle
                              .copyWith(
                                color: widget.messageStyle.adminAuthorTextColor,
                              ),
                        ),
                      ),
                    ),
                  ),

                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Hero(
                        tag:
                            '${widget.message.content.content}',
                        child: switch (widget.message.status) {
                          (MessageStatus.sending) => _ChatAssetImage(
                            value: widget.message.uploadProgress ?? 0,

                            color: widget
                                .messageStyle
                                .clientMessageBackgroundColor,
                            imagePath: widget.message.filePath ?? '',
                          ),
                          (MessageStatus.delivered) => _ImageMessageNetwork(
                            message: widget.message,
                            showSenderName: widget.showSenderName,
                          ),
                          (MessageStatus.seen) => _ImageMessageNetwork(
                            message: widget.message,
                            showSenderName: widget.showSenderName,
                          ),
                          (MessageStatus.error) => Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        },
                      ),

                      const SizedBox(height: 5),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(77),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.all(4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _DateUtility.getFormattedTime(
                                widget.message.date,
                              ),
                              style: widget
                                  .messageStyle
                                  .clientMessageTimeTextStyle
                                  .copyWith(color: Colors.white),
                            ),
                            if (!widget.message.isFromPeer) ...[
                              const SizedBox(width: 6),
                              Icon(
                                switch (widget.message.status) {
                                  (MessageStatus.sending) => Icons.access_time,
                                  (MessageStatus.delivered) => ChatIcons.check,
                                  (MessageStatus.seen) => ChatIcons.doubleCheck,
                                  (MessageStatus.error) => Icons.error_outlined,
                                },
                                size: 16,
                                color: switch (widget.message.status.isError) {
                                  (true) => Colors.redAccent,
                                  (false) => widget.messageStyle.readIconColor,
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        left: 0,
                        bottom: 0,
                        child: Visibility(
                          visible: widget.message.status.isSending,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: borderRadius,
                                color: Colors.black.withAlpha(77),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: _CircularLoading(
                                  value: widget.message.uploadProgress ?? 0,
                                  color: widget
                                      .messageStyle
                                      .clientMessageBackgroundColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ImageMessageNetwork extends StatefulWidget {
  const _ImageMessageNetwork({
    required this.message,
    required this.showSenderName,
  });

  final _MessageModel message;
  final bool showSenderName;

  @override
  State<_ImageMessageNetwork> createState() => _ImageMessageNetworkState();
}

class _ImageMessageNetworkState extends State<_ImageMessageNetwork>
    with AutomaticKeepAliveClientMixin {
  BorderRadius get borderRadius => BorderRadius.circular(16);

  BorderRadius get borderRadiusBottom => const BorderRadius.only(
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(16),
  );

  @override
  void didUpdateWidget(covariant _ImageMessageNetwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _ChatCachedImage(
      value: widget.message.uploadProgress ?? 0,
      imageUrl: '${widget.message.content.content}',
      width: widget.message.width,
      height: widget.message.height,
      borderRadius: widget.message.isFromPeer && widget.showSenderName
          ? borderRadiusBottom
          : borderRadius,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

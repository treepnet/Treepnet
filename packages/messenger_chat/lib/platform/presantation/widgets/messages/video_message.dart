part of messenger_chat;

class _VideoMessage extends StatefulWidget {
  const _VideoMessage({
    required this.showSenderName,
    required this.message,
    required this.messageStyle,
  });

  final bool showSenderName;
  final _MessageModel message;
  final ChatMessageStyle messageStyle;

  @override
  State<_VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<_VideoMessage> {
  @override
  void didUpdateWidget(covariant _VideoMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);
    final borderRadiusBottom = const BorderRadius.only(
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return GestureDetector(
      onTap: () {
        if (widget.message.status.isSending ||
            !widget.message.fileIsNotEmpty ||
            widget.message.status.isError)
          return;
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            settings: RouteSettings(
              name: '/videoViewScreen',
              arguments:
                  '${widget.message.content.content}',
            ),
            builder: (context) => _VideoViewScreen(
              videoUrl:
                  '${widget.message.content.content}',
              imageUrl:
                  '${widget.message.content.png}',
              color: widget.message.isFromPeer
                  ? widget.messageStyle.adminMessageBackgroundColor
                  : widget.messageStyle.clientMessageBackgroundColor,
            ),
          ),
        );
      },
      child: Container(
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.message.isFromPeer
                            ? widget.messageStyle.adminMessageBackgroundColor
                            : widget.messageStyle.clientMessageBackgroundColor,
                      ),
                      alignment: Alignment.center,
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
                            imagePath: widget.message.content.png,
                          ),
                          (MessageStatus.delivered || MessageStatus.seen) =>
                            Builder(
                              builder: (context) => Stack(
                                children: [
                                  _ChatCachedImage(
                                    value: widget.message.uploadProgress ?? 0,
                                    imageUrl:
                                        '${widget.message.content.png}',
                                    width: widget.message.width,
                                    height: widget.message.height,
                                    borderRadius:
                                        widget.message.isFromPeer &&
                                            widget.showSenderName
                                        ? borderRadiusBottom
                                        : borderRadius,
                                  ),
                                  Positioned(
                                    top: 4,
                                    left: 4,

                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(100),
                                        borderRadius: borderRadius,
                                      ),
                                      child: Text(
                                        '${DurationFormatter.format(widget.message.content.duration)}',
                                        style: widget
                                            .messageStyle
                                            .dateSeparatorTextStyle
                                            .copyWith(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  (widget.message.isFromPeer
                                          ? widget
                                                .messageStyle
                                                .clientMessageBackgroundColor
                                          : widget
                                                .messageStyle
                                                .adminMessageBackgroundColor)
                                      .withAlpha((255 * 0.4).round()),
                              borderRadius: BorderRadius.circular(150),
                            ),
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 36,
                              color: (widget.message.isFromPeer
                                  ? widget.messageStyle.adminAudioPlayIconColor
                                  : widget
                                        .messageStyle
                                        .clientAudioPlayIconColor),
                            ),
                          ),
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
                            child: _CircularLoading(
                              value: widget.message.uploadProgress ?? 0,
                              color: widget
                                  .messageStyle
                                  .clientMessageBackgroundColor,
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
}

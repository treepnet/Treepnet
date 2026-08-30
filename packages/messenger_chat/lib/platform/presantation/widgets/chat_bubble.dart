part of messenger_chat;

class _ChatBubble extends StatefulWidget {
  const _ChatBubble({
    required this.isAdmin,
    required this.message,
    required this.messageStyle,
    required this.showDate,
    required this.showSenderName,
    required this.showPeerAvatar,
    required this.date,
    required this.config,
  });

  final bool isAdmin;

  final _MessageModel message;
  final _ConfigModel config;
  final ChatMessageStyle messageStyle;

  final bool showDate;
  final bool showSenderName;
  final bool showPeerAvatar;
  final String date;

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [if (widget.showDate) _dateSeparator(context, widget.date), _bubbleRow(context)],
  );

  Padding _bubbleRow(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
    child: Align(
      alignment: widget.isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: widget.isAdmin ? peerMessage() : userMessage(),
    ),
  );

  Widget _dateSeparator(BuildContext context, String date) => Center(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: widget.messageStyle.adminMessageBackgroundColor,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Text(date, style: widget.messageStyle.dateSeparatorTextStyle),
    ),
  );

  Widget userMessage() => switch (widget.message.contentType) {
    (_ContentType.text) =>
      widget.config.textIsBlock
          ? const SizedBox.shrink()
          : _TextMessage(
              showSenderName: widget.showSenderName,
              message: widget.message,
              messageStyle: widget.messageStyle,
            ),
    (_ContentType.voice) =>
      widget.config.voiceIsBlock
          ? const SizedBox.shrink()
          : _AudioMessage(
              showSenderName: widget.showSenderName,
              message: widget.message,
              messageStyle: widget.messageStyle,
            ),
    (_ContentType.video) =>
      widget.config.videoIsBlock
          ? const SizedBox.shrink()
          : _VideoMessage(
              showSenderName: widget.showSenderName,
              message: widget.message,
              messageStyle: widget.messageStyle,
            ),
    (_ContentType.document) =>
      widget.config.documentIsBlock
          ? const SizedBox.shrink()
          : _FileMessage(
              message: widget.message,
              messageStyle: widget.messageStyle,
              showSenderName: widget.showSenderName,
            ),
    (_ContentType.photo) =>
      widget.config.photoIsBlock
          ? const SizedBox.shrink()
          : _ImageMessage(
              message: widget.message,
              messageStyle: widget.messageStyle,
              showSenderName: widget.showSenderName,
            ),
  };

  Widget peerMessage() => _PeerContent(
    message: widget.message,
    config: widget.config,
    messageStyle: widget.messageStyle,
    showSenderName: widget.showSenderName,
    showPeerAvatar: widget.showPeerAvatar,
  );
}

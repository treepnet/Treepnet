part of messenger_chat;

class _FileMessage extends StatefulWidget {
  const _FileMessage({
    required this.message,
    required this.messageStyle,
    required this.showSenderName,
  });

  final _MessageModel message;
  final ChatMessageStyle messageStyle;
  final bool showSenderName;

  @override
  State<_FileMessage> createState() => _FileMessageState();
}

class _FileMessageState extends State<_FileMessage> {
  @override
  void didUpdateWidget(covariant _FileMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    child: _RippleEffect(
      rippleColor: Colors.blue.shade100,
      onTap: () {
        downloadAndOpenFile(
          '${widget.message.content.content}',
        );
      },
      child: Container(
        width: 230,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: widget.message.isFromPeer
              ? widget.messageStyle.adminMessageBackgroundColor
              : widget.messageStyle.clientMessageBackgroundColor,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: widget.message.isFromPeer &&
                  widget.showSenderName &&
                  widget.message.senderName.isNotEmpty,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.message.isFromPeer
                      ? widget.messageStyle.adminMessageBackgroundColor
                      : widget.messageStyle.clientMessageBackgroundColor,
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(top: 10.0, left: 10),
                child: Text(
                  widget.message.senderName,
                  textAlign: TextAlign.start,
                  style: widget.messageStyle.adminMessageTextStyle.copyWith(
                    color: widget.messageStyle.adminAuthorTextColor,
                  ),
                ),
              ),
            ),
            Visibility(
              visible: (widget.message.isFromPeer &&
                  widget.showSenderName &&
                  widget.message.senderName.isNotEmpty),
              child: const SizedBox(height: 6),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: (widget.message.isFromPeer && widget.showSenderName)
                    ? 0
                    : 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.message.isFromPeer
                          ? widget.messageStyle.adminMessageBackgroundColor
                          : widget.messageStyle.clientMessageBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: switch (widget.message.status) {
                      (MessageStatus.sending) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _CircularLoading(
                          color:
                              widget.messageStyle.clientMessageBackgroundColor,
                          value: widget.message.uploadProgress ?? 0,
                        ),
                      ),
                      (MessageStatus.delivered || MessageStatus.seen) =>
                        _FileIcon(fileName: widget.message.content.content),
                      (MessageStatus.error) => Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          ChatIcons.alertCircle,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.message.content.content.split('/').last,
                          textAlign: TextAlign.start,
                          style: widget.message.isFromPeer
                              ? widget.messageStyle.adminMessageTextStyle
                                    .copyWith(
                                      color: widget
                                          .messageStyle
                                          .clientMessageBackgroundColor,
                                    )
                              : widget.messageStyle.clientMessageTextStyle,
                        ),
                        Text(
                          widget.message.status.isSending
                              ? 'Yuborilyapti...'
                              : '${widget.message.content.size} • ${widget.message.content.content.split('.').last.toUpperCase()}',
                          textAlign: TextAlign.start,
                          style:
                              (widget.message.isFromPeer
                                      ? widget
                                            .messageStyle
                                            .adminMessageTimeTextStyle
                                      : widget
                                            .messageStyle
                                            .clientMessageTimeTextStyle)
                                  .copyWith(
                                    fontSize: 12,
                                    color: widget.message.status.isSending
                                        ? Colors.blueAccent
                                        : null,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0, right: 12),

              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    _DateUtility.getFormattedTime(widget.message.date),
                    style: widget.message.isFromPeer
                        ? widget.messageStyle.adminMessageTimeTextStyle
                        : widget.messageStyle.clientMessageTimeTextStyle,
                  ),
                  if (!widget.message.isFromPeer) ...[
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
                        (false) => widget.messageStyle.readIconColor,
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> downloadAndOpenFile(String url) async {
    try {
      // Transport to'liq manzil beradi, shuning uchun bu yerda hech qanday
      // maxsus sozlama kerak emas.
      final dio = Dio();
      final tempDir = await getTemporaryDirectory();
      final fileName = url.split('/').last;
      final String fullUrl = url;

      final filePath = '${tempDir.path}/$fileName';
      final localFile = File(filePath);
      final mimeType = _MimetypeDetector.getMimeType(filePath);

      // Helper to show SnackBar
      void showMessage(String message) {
        MessengerChat.controller.showToast(message, type: ToastType.error);
      }

      // 1. Check if file already exists in cache
      if (await localFile.exists()) {
        _ChatLogger.print(
          'Fayl keshdan topildi, ochilmoqda: $filePath ($mimeType)',
        );
        final result = await OpenFilex.open(filePath, type: mimeType);
        if (result.type != ResultType.done) {
          _ChatLogger.print(
            _AppTexts.fileOpenError,
          );
          if (result.type == ResultType.noAppToOpen) {
            showMessage(_AppTexts.noAppFound);
          } else {
            showMessage(result.message);
          }
        }
        return;
      }

      // 2. If not in cache, download it
      _ChatLogger.print('Fayl yuklab olinmoqda: $fullUrl');
      final response = await dio.download(fullUrl, filePath);

      if (response.statusCode == 200) {
        _ChatLogger.print('Fayl muvaffaqiyatli yuklandi: $filePath');
        final result = await OpenFilex.open(filePath, type: mimeType);
        if (result.type != ResultType.done) {
          _ChatLogger.print('Faylni ochishda xatolik: ${result.message}');
          if (result.type == ResultType.noAppToOpen) {
            showMessage(_AppTexts.noAppFound);
          } else {
            showMessage(result.message);
          }
        }
      } else {
        showMessage(_AppTexts.fileOpenError);
        _ChatLogger.print('Yuklashda xatolik: ${response.statusCode}');
      }
    } catch (e) {
      _ChatLogger.print('downloadAndOpenFile xatoligi: $e');
    }
  }
}

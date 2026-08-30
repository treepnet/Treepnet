part of messenger_chat;

class _AudioMessage extends StatefulWidget {
  const _AudioMessage({
    required this.message,
    required this.showSenderName,
    required this.messageStyle,
  });

  final bool showSenderName;
  final _MessageModel message;
  final ChatMessageStyle messageStyle;

  @override
  State<_AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<_AudioMessage>
    with AutomaticKeepAliveClientMixin {
  late final _AudioMessageController _controller;
  double? _waveformWidth;

  @override
  void initState() {
    super.initState();
    _controller = _AudioMessageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _waveformWidth = MediaQuery.of(context).size.width * 0.5;
        });
      }
    });
  }

  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AudioMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final message = widget.message;
    final style = widget.messageStyle;
    final isAdmin = message.isFromPeer;

    final bgColor = isAdmin
        ? style.adminMessageBackgroundColor
        : style.clientMessageBackgroundColor;

    final waveColor = isAdmin
        ? style.adminAudioWaveColor
        : style.clientAudioWaveColor;

    final playColor = isAdmin
        ? style.adminAudioPlayIconColor
        : style.clientAudioPlayIconColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isAdmin
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Visibility(
                  visible: isAdmin &&
                      widget.showSenderName &&
                      widget.message.senderName.isNotEmpty,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 12),
                    child: Text(
                      message.senderName,
                      textAlign: TextAlign.start,
                      style: widget.messageStyle.adminMessageTextStyle.copyWith(
                        color: widget.messageStyle.adminAuthorTextColor,
                      ),
                    ),
                  ),
                ),

                Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        top: widget.showSenderName ? 6 : 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildPlayerControls(
                            waveColor,
                            playColor,
                            bgColor,
                            '${widget.message.content.content}',
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<_AudioMessageData>(
                            valueListenable: _controller.audioMessage,
                            builder: (_, data, __) {
                              final bool isDefaultZero =
                                  data.duration == '0:00';
                              final String displayDuration =
                                  (isDefaultZero &&
                                      widget
                                          .message
                                          .content
                                          .duration
                                          .isNotEmpty)
                                  ? DurationFormatter.format(
                                      widget.message.content.duration,
                                    )
                                  : data.duration;
                              return Padding(
                                padding: const EdgeInsets.only(left: 44),
                                child: Text(
                                  displayDuration,
                                  style: isAdmin
                                      ? style.adminMessageTimeTextStyle
                                      : style.clientMessageTimeTextStyle,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      right: 12,
                      child: Row(
                        children: [
                          Text(
                            _DateUtility.getFormattedTime(message.date),
                            style: isAdmin
                                ? style.adminMessageTimeTextStyle
                                : style.clientMessageTimeTextStyle,
                          ),
                          if (!isAdmin) ...[
                            const SizedBox(width: 6),
                            Icon(
                              message.isReadMessage
                                  ? ChatIcons.doubleCheck
                                  : ChatIcons.check,
                              color: style.readIconColor,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlayerControls(
    Color waveColor,
    Color playColor,
    Color bgColor,
    String file,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ValueListenableBuilder<_AudioMessageData>(
        valueListenable: _controller.audioMessage,
        builder: (_, data, __) => GestureDetector(
          onTap: () => _controller.togglePlay(file),
          child: Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              border: widget.message.status.isSending
                  ? null
                  : Border.all(color: playColor, width: 2),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Visibility(
                  visible: widget.message.status.isSending,
                  child: _CircularLoading(
                    color: playColor,
                    strokeWidth: 2,
                    value: widget.message.uploadProgress ?? 0,
                  ),
                ),
                Icon(
                  data.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: playColor,
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onHorizontalDragUpdate: (details) {
          final localX = details.localPosition.dx;
          _controller.seekByTap(localX, _waveformWidth ?? 0, file);
        },
        onTapDown: (details) {
          final localX = details.localPosition.dx;
          _controller.seekByTap(localX, _waveformWidth ?? 0, file);
        },
        child: Container(
          width: _waveformWidth,
          height: 24,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ValueListenableBuilder<_AudioMessageData?>(
            valueListenable: _controller.audioMessage,
            builder: (_, data, __) {
              if (data == null) return const SizedBox.shrink();

              final progress = data.progress;

              return ShaderMask(
                shaderCallback: (bounds) {
                  final width = bounds.width;
                  return LinearGradient(
                    colors: [
                      waveColor,
                      waveColor,
                      waveColor.withAlpha((255.0 * 0.6).round()),
                      waveColor.withAlpha((255.0 * 0.6).round()),
                    ],
                    stops: [
                      0.0,
                      progress.clamp(0.0, 1.0),
                      progress.clamp(0.0, 1.0),
                      1.0,
                    ],
                  ).createShader(Rect.fromLTWH(0, 0, width, bounds.height));
                },
                blendMode: BlendMode.srcIn,
                child: widget.message.content.svg.isNotEmpty
                    ? SvgPicture.network(
                        widget.message.voiceWave,
                        height: 24,
                        fit: BoxFit.fill,
                        width: _waveformWidth,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildFallbackWaveform(),
                      )
                    : _buildFallbackWaveform(),
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _buildFallbackWaveform() {
    return SizedBox(
      width: _waveformWidth,
      height: 24,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          20,
          (index) => Container(
            width: 2,
            height: 6 + (index % 4) * 3.0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

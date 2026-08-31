part of messenger_chat;

class _ChatTextField extends StatefulWidget {
  const _ChatTextField({
    required this.style,
    required this.listScrollController,
    required this.voiceController,
    required this.focusNode,
    this.controller,
    this.config,
    this.onSendMessage,
    this.isEmojiMode = false,
    this.onEmojiToggled,
  });

  final TextEditingController? controller;
  final FocusNode focusNode;
  final VoidCallback? onSendMessage;
  final _ConfigModel? config;
  final ChatTextFieldStyle style;
  final ScrollController listScrollController;
  final _VoiceRecorder voiceController;
  final bool isEmojiMode;
  final Function(bool mode, bool show)? onEmojiToggled;

  @override
  State<_ChatTextField> createState() => _ChatTextFieldState();
}

class _ChatTextFieldState extends State<_ChatTextField> {
  // No local _showEmoji state anymore, relying on widget.isEmojiMode and parent state

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _ChatTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      // Keyboard gained focus, ensure picker is rendered underneath
      widget.onEmojiToggled?.call(false, true);
    }
  }

  Clip get clip => Clip.none;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isEmojiMode) {
          widget.onEmojiToggled?.call(false, false);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: _MaybeBlur(
                      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              widget.style.inputFillColor == Colors.transparent
                              ? (Theme.of(context).brightness ==
                                        Brightness.light
                                    ? _surfaceColor(Colors.white, 0.6)
                                    : _surfaceColor(Colors.black, 0.4))
                              : widget.style.inputFillColor,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color:
                                (Theme.of(context).brightness ==
                                    Brightness.light
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1 * 0.3)),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Attachment Button
                            if (!(widget.config?.attachmentIsBlock ?? false))
                              ValueListenableBuilder<_VoiceServiceData>(
                                valueListenable:
                                    widget.voiceController.audioData,
                                builder: (_, voiceData, __) =>
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: widget.controller!,
                                      builder: (_, textValue, __) =>
                                          _AnimatedVisible(
                                            visible:
                                                !voiceData.isRecording &&
                                                textValue.text.isEmpty,
                                            child: Container(
                                              height: 44,
                                              alignment: Alignment.center,
                                              child: _GeneralEffectsButton(
                                                onTap: () =>
                                                    handleUploadImage(context),
                                                constraints:
                                                    const BoxConstraints(),
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    10.0,
                                                  ),
                                                  child: Icon(
                                                    ChatIcons.paperclip,
                                                    color: widget
                                                        .style
                                                        .attachmentIconColor
                                                        .withOpacity(0.7),
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                    ),
                              ),
                            // Text Input
                            Flexible(
                              child: ValueListenableBuilder<_VoiceServiceData>(
                                valueListenable:
                                    widget.voiceController.audioData,
                                builder: (context, voiceData, _) {
                                  final accentColor =
                                      widget.style.inputCursorColor ??
                                      const Color(0xff1064FF);

                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      textSelectionTheme:
                                          TextSelectionThemeData(
                                            cursorColor: accentColor,
                                            selectionColor: accentColor
                                                .withOpacity(0.2),
                                            selectionHandleColor: accentColor,
                                          ),
                                    ),
                                    child: Stack(
                                      children: [
                                        TextFormField(
                                          controller: widget.controller,
                                          focusNode: widget.focusNode,
                                          clipBehavior: Clip.hardEdge,
                                          enabled:
                                              !(widget.config?.textIsBlock ??
                                                  false),
                                          style: widget.style.inputTextStyle,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          cursorColor:
                                              widget.style.inputCursorColor,
                                          cursorHeight: 18,
                                          textInputAction:
                                              TextInputAction.newline,
                                          keyboardType: TextInputType.multiline,
                                          minLines: 1,
                                          maxLines: 6,
                                          onTap: () {
                                            if (widget.isEmojiMode) {
                                              widget.onEmojiToggled?.call(
                                                false,
                                                true,
                                              );
                                            }
                                          },
                                          onFieldSubmitted: (value) {
                                            widget.onSendMessage?.call();
                                            widget.focusNode.requestFocus();
                                          },
                                          onChanged: (value) => typing(),
                                          cursorWidth: 2.0,
                                          decoration: InputDecoration(
                                            // Yozib olish paytida panel maydon
                                            // ustiga qoplama bo'lib tushadi,
                                            // shuning uchun hint ko'rinmasligi
                                            // kerak.
                                            hintText: voiceData.isRecording
                                                ? ''
                                                : _AppTexts.writeHere,
                                            hintFadeDuration: const Duration(
                                              milliseconds: 250,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.transparent,
                                            contentPadding:
                                                const EdgeInsets.fromLTRB(
                                                  12,
                                                  10,
                                                  12,
                                                  10,
                                                ),
                                            hintStyle:
                                                widget.style.inputHintTextStyle,
                                            focusedBorder: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                          ),
                                        ),
                                        if (voiceData.isRecording)
                                          Positioned.fill(
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    _AnimatedVisible(
                                                      visible:
                                                          voiceData.isRecording,
                                                      child: Container(
                                                        height: 36,
                                                        width:
                                                            MediaQuery.of(
                                                              context,
                                                            ).size.width *
                                                            0.72,
                                                        decoration: BoxDecoration(
                                                          color: widget
                                                              .style
                                                              .inputBackgroundColor,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.only(
                                                                    left: 12,
                                                                  ),
                                                              child: Container(
                                                                width: 8,
                                                                height: 8,
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .red,
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  boxShadow: [
                                                                    BoxShadow(
                                                                      color: Colors
                                                                          .red
                                                                          .withOpacity(
                                                                            0.4,
                                                                          ),
                                                                      blurRadius:
                                                                          4,
                                                                      spreadRadius:
                                                                          1,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              voiceData
                                                                      .isRecording
                                                                  ? voiceData
                                                                        .currentDuration
                                                                  : '0:00',
                                                              style: widget
                                                                  .style
                                                                  .cancelRecordingTextStyle
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            ),
                                                            // Expanded - qolgan
                                                            // joyni egallaydi;
                                                            // aks holda uzun
                                                            // tarjimalarda
                                                            // (masalan kirill)
                                                            // qator o'ngga
                                                            // chiqib ketadi.
                                                            Expanded(
                                                              child: Center(
                                                                child: Transform.translate(
                                                                  offset: Offset(
                                                                    voiceData
                                                                            .isLocked
                                                                        ? -70
                                                                        : voiceData
                                                                              .dragLeftOffset,
                                                                    0,
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      const Icon(
                                                                        ChatIcons
                                                                            .chevronLeft,
                                                                        size:
                                                                            14,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Flexible(
                                                                        child: Text(
                                                                          _AppTexts
                                                                              .cancelRecording,
                                                                          maxLines:
                                                                              1,
                                                                          overflow:
                                                                              TextOverflow.ellipsis,
                                                                          style: widget
                                                                              .style
                                                                              .cancelRecordingTextStyle,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 14,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Emoji Toggle Button
                            ValueListenableBuilder<_VoiceServiceData>(
                              valueListenable: widget.voiceController.audioData,
                              builder: (_, data, __) => _AnimatedVisible(
                                visible: !data.isRecording,
                                child: Container(
                                  height: 44,
                                  alignment: Alignment.center,
                                  child: _GeneralEffectsButton(
                                    onTap: () async {
                                      if (widget.isEmojiMode) {
                                        widget.focusNode.requestFocus();
                                        // Picker remains showEmoji=true (frozen under keyboard)
                                        widget.onEmojiToggled?.call(
                                          false,
                                          true,
                                        );
                                      } else {
                                        widget.focusNode.unfocus();
                                        // Small delay to allow keyboard to start closing,
                                        // picker takes over explicit mode immediately
                                        await Future.delayed(
                                          const Duration(milliseconds: 50),
                                        );
                                        widget.onEmojiToggled?.call(true, true);
                                      }
                                    },
                                    constraints: const BoxConstraints(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Icon(
                                        widget.isEmojiMode
                                            ? ChatIcons.keyboard
                                            : ChatIcons.smile,
                                        color: widget.style.attachmentIconColor
                                            .withOpacity(0.7),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Mic/Send button area
                ValueListenableBuilder<_VoiceServiceData>(
                  valueListenable: widget.voiceController.audioData,
                  builder: (_, data, __) => Stack(
                    alignment: Alignment.bottomRight,
                    clipBehavior: Clip.none,
                    children: [
                      // The send button must always be available for text; only
                      // the mic (empty-text fallback) is gated on voice being
                      // enabled. Previously this `if` hid BOTH, so text-only
                      // mode (ChatFeatures voice:false) had no way to send.
                      Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 2),
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: widget.controller!,
                            builder: (context, textValue, _) {
                              final sendEnabled = textValue.text.isNotEmpty;
                              return AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    ),
                                child: sendEnabled
                                    ? _GeneralEffectsButton(
                                        key: const ValueKey('send'),
                                        onTap: () =>
                                            widget.onSendMessage?.call(),
                                        constraints: const BoxConstraints(),
                                        borderRadius: BorderRadius.circular(21),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            21,
                                          ),
                                          child: _MaybeBlur(
                                            filter: ui.ImageFilter.blur(
                                              sigmaX: 10,
                                              sigmaY: 10,
                                            ),
                                            child: Container(
                                              width: 42,
                                              height: 42,
                                              decoration: BoxDecoration(
                                                color:
                                                    (widget
                                                                .style
                                                                .sendBackgroundColor ==
                                                            null ||
                                                        widget
                                                                .style
                                                                .sendBackgroundColor ==
                                                            Colors.transparent)
                                                    ? const Color(
                                                        0xff1064FF,
                                                      ).withValues(alpha: 0.65)
                                                    : widget
                                                          .style
                                                          .sendBackgroundColor!
                                                          .withValues(
                                                            alpha: 0.65,
                                                          ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      (Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.light
                                                      ? Colors.white.withValues(
                                                          alpha: 0.3,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: 0.1 * 0.3,
                                                        )),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  ChatIcons.send,
                                                  color: widget
                                                      .style
                                                      .sendIconColor,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : (widget.config?.voiceIsBlock ?? false)
                                    ? const SizedBox.shrink()
                                    : _MicButton(
                                        key: const ValueKey('mic'),
                                        voiceController: widget.voiceController,
                                        chatTextFieldStyle: widget.style,
                                        sendEnabled: true,
                                        data: data,
                                        listScrollController:
                                            widget.listScrollController,
                                      ),
                              );
                            },
                          ),
                        ),
                      // Lock Indicator for recording
                      Positioned(
                        bottom: 54,
                        right: 0,
                        child: _AnimatedVisible(
                          visible: data.isRecording,
                          child: _LockIndicator(data: data),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Timer? _typingDebounce;

  void typing() {
    if (_typingDebounce?.isActive ?? false) return;
    unawaited(_ChatSocket.sendTyping(isTyping: true));
    _typingDebounce = Timer(const Duration(seconds: 2), () {});
  }

  void handleUploadImage(BuildContext context) async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      final Message message = await showCupertinoModalPopup(
        context: context,
        barrierColor: const Color(0xffDEE9FF).withValues(alpha: 0.3),
        builder: (context) => const SafeArea(child: _FileUploadModalSheet()),
      );

      if (!mounted) return;

      context.read<ChatCubit>().sendFileMessage(
        message.content,
        message.size,
        context: context,
        downScrollCallback: () {
          widget.listScrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        },
      );
    } catch (e) {
      _ChatLogger.failure(e.toString());
    }
  }
}

class _LockIndicator extends StatelessWidget {
  const _LockIndicator({required this.data});
  final _VoiceServiceData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: 36,
          height: data.isLocked ? 36 : 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: data.isLocked
              ? const Icon(ChatIcons.lock, color: Colors.blue, size: 18)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    const Icon(ChatIcons.lock, color: Colors.black, size: 18),
                    const Spacer(),
                    Center(
                      child: Transform.translate(
                        offset: Offset(0, data.dragTopOffset),
                        child: const Icon(
                          ChatIcons.chevronUp,
                          color: Colors.black,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
        ),
      ],
    );
  }
}

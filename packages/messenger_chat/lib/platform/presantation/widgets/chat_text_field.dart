part of messenger_chat;

/// The longest message the text field takes.
const _maxMessageLength = 4000;

/// The message input: text only. Voice recording, attachments and the emoji
/// panel used to live here too; the app never turned them on, and they pulled
/// a dozen native libraries into the build.
class _ChatTextField extends StatefulWidget {
  const _ChatTextField({
    required this.style,
    required this.focusNode,
    this.controller,
    this.config,
    this.onSendMessage,
  });

  final TextEditingController? controller;
  final FocusNode focusNode;
  final VoidCallback? onSendMessage;
  final _ConfigModel? config;
  final ChatTextFieldStyle style;

  @override
  State<_ChatTextField> createState() => _ChatTextFieldState();
}

class _ChatTextFieldState extends State<_ChatTextField> {
  @override
  void dispose() {
    _typingDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.style.inputCursorColor ?? const Color(0xff1064FF);

    return Padding(
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
                    color: widget.style.inputFillColor == Colors.transparent
                        ? (Theme.of(context).brightness == Brightness.light
                              ? _surfaceColor(Colors.white, 0.6)
                              : _surfaceColor(Colors.black, 0.4))
                        : widget.style.inputFillColor,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: (Theme.of(context).brightness == Brightness.light
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1 * 0.3)),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textSelectionTheme: TextSelectionThemeData(
                        cursorColor: accentColor,
                        selectionColor: accentColor.withOpacity(0.2),
                        selectionHandleColor: accentColor,
                      ),
                    ),
                    child: TextFormField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      // Well under the server's 8000, so a long text stops
                      // here instead of failing to send with no reason.
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_maxMessageLength),
                      ],
                      clipBehavior: Clip.hardEdge,
                      enabled: !(widget.config?.textIsBlock ?? false),
                      style: widget.style.inputTextStyle,
                      textAlignVertical: TextAlignVertical.center,
                      cursorColor: widget.style.inputCursorColor,
                      cursorHeight: 18,
                      textInputAction: TextInputAction.newline,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 6,
                      onFieldSubmitted: (value) {
                        widget.onSendMessage?.call();
                        widget.focusNode.requestFocus();
                      },
                      onChanged: (value) => typing(),
                      cursorWidth: 2.0,
                      decoration: InputDecoration(
                        hintText: _AppTexts.writeHere,
                        hintFadeDuration: const Duration(milliseconds: 250),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.fromLTRB(
                          12,
                          10,
                          12,
                          10,
                        ),
                        hintStyle: widget.style.inputHintTextStyle,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Send: shown once there is something to send.
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller!,
              builder: (context, textValue, _) {
                final sendEnabled = textValue.text.trim().isNotEmpty;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: sendEnabled
                      ? _sendButton(context)
                      : const SizedBox.shrink(key: ValueKey('none')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sendButton(BuildContext context) => _GeneralEffectsButton(
    key: const ValueKey('send'),
    onTap: () => widget.onSendMessage?.call(),
    constraints: const BoxConstraints(),
    borderRadius: BorderRadius.circular(21),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: _MaybeBlur(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            // A provided colour is used as-is (solid) — only the built-in
            // default stays translucent.
            color:
                (widget.style.sendBackgroundColor == null ||
                    widget.style.sendBackgroundColor == Colors.transparent)
                ? const Color(0xff1064FF).withValues(alpha: 0.65)
                : widget.style.sendBackgroundColor!,
            shape: BoxShape.circle,
            border: Border.all(
              color: (Theme.of(context).brightness == Brightness.light
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1 * 0.3)),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              ChatIcons.send,
              color: widget.style.sendIconColor,
              size: 20,
            ),
          ),
        ),
      ),
    ),
  );

  Timer? _typingDebounce;

  void typing() {
    if (_typingDebounce?.isActive ?? false) return;
    unawaited(_ChatSocket.sendTyping(isTyping: true));
    _typingDebounce = Timer(const Duration(seconds: 2), () {});
  }
}

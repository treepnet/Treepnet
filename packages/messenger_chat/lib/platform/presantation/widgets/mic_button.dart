part of messenger_chat;

class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.chatTextFieldStyle,
    required this.voiceController,
    required this.sendEnabled,
    required this.data,
    required this.listScrollController,
    super.key,
  });

  final ChatTextFieldStyle chatTextFieldStyle;
  final ScrollController listScrollController;
  final _VoiceRecorder voiceController;
  final _VoiceServiceData data;
  final bool sendEnabled;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  double _progress = 0.0;
  double _startX = 0.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      // Voice recording is disabled in TreepNet (ChatFeatures voice:false), so
      // the old super_tooltip "swipe to send" hint was removed (its flat API is
      // incompatible with super_tooltip 2.1.1). The mic gesture stays intact.
      return GestureDetector(
          // Ichkarida IgnorePointer bor, shuning uchun deferToChild (standart)
          // rejimida bu GestureDetector umuman teginish olmaydi - tugma o'z
          // maydoni bo'yicha hit-test qilishi shart.
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            widget.voiceController.onLongPressStart(details.globalPosition);
          },
          onLongPressMoveUpdate: (details) {
            widget.voiceController.onLongPressMoveUpdate(
              context,
              details.globalPosition,
            );
          },
          onLongPressEnd: (_) {
            widget.voiceController.onLongPressEnd(
              context,
              success: () {
                widget.listScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeIn,
                );
              },
            );
          },
          onTap: () {
            widget.voiceController.onTap(context);
          },
          onHorizontalDragStart: (details) {
            _startX = details.localPosition.dx;
          },
          onHorizontalDragUpdate: (details) {
            final double dragged = _startX - details.localPosition.dx;
            final double relativeProgress = (dragged / width).clamp(0.0, 1.0);

            setState(() {
              _progress = relativeProgress;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_progress >= 0.5) {
              widget.voiceController.stopRecording();
            }

            setState(() {
              _progress = 0.0;
            });
          },
          child: Center(
            child: _MicPulseAnimation(
              scale: widget.data.amplitude,
              isRecording: widget.data.isRecording,
              visible: widget.sendEnabled,
              color: widget.chatTextFieldStyle.microphoneBackgroundColor,
              child: IgnorePointer(
                ignoring: true,
                child: _GeneralEffectsButton(
                  onTap: () {}, // Handled by gesture detector
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
                          color:
                              (widget
                                      .chatTextFieldStyle
                                      .microphoneBackgroundColor ==
                                  Colors.transparent)
                              ? const Color(0xff1064FF).withValues(alpha: 0.65)
                              : widget
                                    .chatTextFieldStyle
                                    .microphoneBackgroundColor
                                    .withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                (Theme.of(context).brightness == Brightness.light
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1 * 0.3)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            widget.data.isLocked && widget.data.isRecording
                                ? ChatIcons.send
                                : ChatIcons.mic,
                            color: widget.chatTextFieldStyle.microphoneIconColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      );
    },
  );
}


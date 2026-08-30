part of messenger_chat;

final ChatController<ChatModel> _chatController = ChatController<ChatModel>();

class MessengerChat extends StatefulWidget {
  const MessengerChat({
    required this.chatDecoration,
    required this.chatTextFieldStyle,
    required this.messageStyle,
    required this.peer,
    required this.lang,
    this.chatAppBarStyle,
    super.key,
  });

  /// Kim bilan yozishilayotgani. App bar shu ma'lumotni ko'rsatadi va
  /// xabarlar shu foydalanuvchidan kelgani aniqlanadi.
  final ChatUser peer;
  final ChatLanguage lang;
  final ChatDecoration chatDecoration;
  final ChatMessageStyle messageStyle;
  final ChatTextFieldStyle chatTextFieldStyle;
  final ChatAppBarStyle? chatAppBarStyle;

  static const MethodChannel _channel = MethodChannel('messenger_chat');

  static Future<String> getDeviceId() async {
    try {
      final String? deviceId = await _channel.invokeMethod('getUniqueDeviceId');
      return deviceId ?? '';
    } catch (e) {
      debugPrint('[MessengerChat.getDeviceId Error] $e');
      return '';
    }
  }

  /// Plaginni ishga tayyorlaydi.
  ///
  /// Chat ekranini ochishdan oldin bir marta chaqirilishi shart.
  ///
  /// [transport] - ilovaning o'z backendiga ko'prik ([ChatTransport] ni
  /// amalga oshiruvchi sinf). [me] - shu qurilmadagi foydalanuvchi; xabar
  /// qaysi tomonda chizilishi shu identifikator bilan aniqlanadi.
  static Future<void> init({
    required ChatTransport transport,
    required ChatUser me,
    ChatFeatures? features,
    ChatLanguage? lang,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    _ChatRuntime.instance.configure(
      transport: transport,
      me: me,
      features: features,
    );
    _ChatLocalizations.instance.initialize(lang);
  }

  /// Suhbat yopilganda resurslarni bo'shatadi.
  static Future<void> release() async {
    await _ChatSocket.dispose();
    await _ChatRuntime.instance.reset();
  }

  /// Transportga ulanadi. Odatda ekranning o'zi chaqiradi.
  static Future<void> connectTransport({required ChatCubit cubit}) =>
      _ChatSocket.connect(cubit: cubit);

  static Future<void> disconnectTransport() => _ChatSocket.dispose();

  /// Suhbatdosh ismi va avatari ko'rsatilgan app bar.
  static PreferredSizeWidget appBar(
    ChatAppBarStyle chatAppBarStyle, {
    required ChatUser peer,
  }) => _ChatAppBar(style: chatAppBarStyle, peer: peer);

  static MessengerChatController get configController => MessengerChatController();

  static ChatController<ChatModel> get controller => _chatController;

  static MessengerChat light({
    required ChatUser peer,
    required ChatLanguage lang,
    ChatAppBarStyle? chatAppBarStyle,
  }) =>
      MessengerChat(
        peer: peer,
        lang: lang,
        chatAppBarStyle: chatAppBarStyle,
        chatDecoration: ChatDecoration(
          backgroundColor: const Color(0xffEAF3FD),
          backgroundImagePng: 'assets/images/background.png',
          backgroundImageSvg: 'assets/images/bg_pattern.svg',
          backgroundSvgColor: const Color(0xff1064FF).withOpacity(0.3),
        ),
        messageStyle: const ChatMessageStyle(
          clientMessageTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.white,
          ),
          adminMessageTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          dateSeparatorTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Color(0xff151515),
          ),
          clientMessageTimeTextStyle: TextStyle(color: Colors.white),
          adminMessageTimeTextStyle: TextStyle(color: Color(0xff626262)),
          adminMessageBackgroundColor: Color(0xffFFFFFF),
          clientMessageBackgroundColor: Color(0xff1064FF),
          adminProfileBackgroundColor: Color(0xff1064FF),
          fileIconColor: Color(0xff1064FF),
          adminProfileIconSvg: 'assets/icons/support.svg',
          fileIconSvg: 'assets/icons/support.svg',
          readIconColor: Colors.white,
          adminAuthorTextColor: Colors.blueGrey,
          clientAudioPlayIconColor: Colors.white,
          adminAudioPlayIconColor: Colors.blueGrey,
          clientAudioWaveColor: Colors.white,
          adminAudioWaveColor: Colors.blueGrey,
        ),
        chatTextFieldStyle: const ChatTextFieldStyle(
          sendIconPath: 'assets/icons/arrow-up-sm.svg',
          closeIconPath: 'assets/icons/close.svg',
          microphoneIconPath: 'assets/icons/microphone-01.svg',
          attachmentIconPath: 'assets/icons/attachment.svg',
          attachmentIconColor: Color(0xff939393),
          sendBackgroundColor: Color(0xff1064FF),
          sendIconColor: Colors.white,
          closeIconColor: Colors.white,
          enabledBorderColor: Colors.transparent,
          focusedBorderColor: Colors.transparent,
          inputBackgroundColor: Colors.transparent,
          inputFillColor: Colors.transparent,
          microphoneBackgroundColor: Color(0xff1064FF),
          microphoneIconColor: Colors.white,
          inputCursorColor: Colors.black,
          inputHintTextStyle: TextStyle(color: Colors.black54, fontSize: 16),
          inputTextStyle: TextStyle(color: Colors.black, fontSize: 16),
        ),
      );

  static MessengerChat dark({
    required ChatUser peer,
    required ChatLanguage lang,
    ChatAppBarStyle? chatAppBarStyle,
  }) =>
      MessengerChat(
        peer: peer,
        lang: lang,
        chatAppBarStyle: chatAppBarStyle,
        chatDecoration: ChatDecoration(
          backgroundColor: const Color(0xff0F172A),
          backgroundImagePng: 'assets/images/background.png',
          backgroundImageSvg: 'assets/images/bg_pattern.svg',
          backgroundSvgColor: Colors.white.withOpacity(0.1),
        ),
        messageStyle: const ChatMessageStyle(
          clientMessageTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.white,
          ),
          adminMessageTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.white,
          ),
          dateSeparatorTextStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Color(0xff9CA3AF),
          ),
          clientMessageTimeTextStyle: TextStyle(color: Color(0xffD1D5DB)),
          adminMessageTimeTextStyle: TextStyle(color: Color(0xff9CA3AF)),
          adminMessageBackgroundColor: Color(0xff1F2937),
          clientMessageBackgroundColor: Color(0xff2563EB),
          adminProfileBackgroundColor: Color(0xff2563EB),
          fileIconColor: Color(0xff93C5FD),
          adminProfileIconSvg: 'assets/icons/support.svg',
          fileIconSvg: 'assets/icons/support.svg',
          readIconColor: Colors.white,
          adminAuthorTextColor: Color(0xffE5E7EB),
          clientAudioPlayIconColor: Colors.white,
          adminAudioPlayIconColor: Color(0xff93C5FD),
          clientAudioWaveColor: Colors.white,
          adminAudioWaveColor: Color(0xff93C5FD),
        ),
        chatTextFieldStyle: const ChatTextFieldStyle(
          sendIconPath: 'assets/icons/arrow-up-sm.svg',
          closeIconPath: 'assets/icons/close.svg',
          microphoneIconPath: 'assets/icons/microphone-01.svg',
          attachmentIconPath: 'assets/icons/attachment.svg',
          attachmentIconColor: Color(0xff9CA3AF),
          sendBackgroundColor: Color(0xff2563EB),
          sendIconColor: Colors.white,
          closeIconColor: Colors.white,
          enabledBorderColor: Colors.transparent,
          focusedBorderColor: Colors.transparent,
          inputBackgroundColor: Colors.transparent,
          inputFillColor: Colors.transparent,
          microphoneBackgroundColor: Color(0xff2563EB),
          microphoneIconColor: Colors.white,
          inputCursorColor: Colors.white,
          inputHintTextStyle: TextStyle(color: Color(0xff9CA3AF), fontSize: 16),
          inputTextStyle: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );

  static void socketDataClear() {
    _ChatSocket.dispose();
    _SecureStorage.storage.deleteAll();
  }

  static NotificationController notificationController =
      NotificationController();

  static final List<StreamSubscription> _apiSubscriptions = [];

  static StreamSubscription onUnreadCount(void Function(int unread) callback) {
    final sub = controller.stream
        .map((e) => e.unreadMessageData.unreadCount)
        .listen(callback);
    _apiSubscriptions.add(sub);
    return sub;
  }

  static StreamSubscription onChatSummary(
    void Function(ChatModel summary) callback,
  ) {
    final sub = controller.stream.listen(callback);
    _apiSubscriptions.add(sub);
    return sub;
  }

  static void disposeCallbacks() {
    for (final s in _apiSubscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _apiSubscriptions.clear();
  }

  @override
  State<MessengerChat> createState() => _MessengerChatState();
}

class _MessengerChatState extends State<MessengerChat> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final _VoiceRecorder _voiceController = _VoiceRecorder();
  final ScrollController _listScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<ChatConnectionStatus>? _connectionSteam;
  ChatCubit? _cubit;
  bool _isInternalCubit = false;
  final ValueNotifier<bool> _showEmojiNotifier = ValueNotifier<bool>(false);
  late ValueNotifier<bool> _isEmojiModeNotifier;
  late ValueNotifier<double> _bottomPaddingNotifier;
  final GlobalKey _bottomAreaKey = GlobalKey();
  final ValueNotifier<bool> _showScrollDownNotifier = ValueNotifier<bool>(
    false,
  );

  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Suhbatdoshni birinchi chizishdan oldin o'rnatamiz - xabar yonidagi
    // avatar shu ma'lumotni o'qiydi.
    _ChatRuntime.instance.setPeer(widget.peer);

    try {
      _cubit = context.read<ChatCubit>();
    } catch (_) {
      _cubit = ChatCubit(ChatRepositoryImpl());
      _isInternalCubit = true;
    }
    _isEmojiModeNotifier = ValueNotifier<bool>(false);
    _bottomPaddingNotifier = ValueNotifier<double>(0.0);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _updateBottomPadding();
      _ChatLocalizations.instance.initialize(widget.lang);

      await initStorage();

      if (_isInternalCubit) {
        _cubit?.applyFeatures();
        _cubit?.getMessages(isRefresh: true);
        _cubit?.markAsRead();
      } else {
        _cubit?.markAsRead();
      }

      initBaseUrl();
      await setInitialTexts();

      _connectionSteam = MessengerChat.controller.connectionStream.listen((
        connection,
      ) {
        if (!mounted) return;

        if (connection == ChatConnectionStatus.connected)
          _cubit?.getMessagesWhenOnline();
      });

      _listScrollController.addListener(() {
        if (!mounted) return;
        if (_listScrollController.offset > 200 &&
            !_showScrollDownNotifier.value) {
          _showScrollDownNotifier.value = true;
        } else if (_listScrollController.offset <= 200 &&
            _showScrollDownNotifier.value) {
          _showScrollDownNotifier.value = false;
        }
      });
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset == 0) {
      if (!_isEmojiModeNotifier.value && _showEmojiNotifier.value) {
        _showEmojiNotifier.value = false;
      }
    }
  }

  Future<void> setInitialTexts() async {
    await _SecureStorage.setFirstTime(DateTime.now().toUtc().toIso8601String());
  }

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final message = _controller.text;
    _controller.clear();

    final key = DateTime.now().millisecondsSinceEpoch.toString();
    _cubit?.addMessage(
      _MessageModel.initial.copyWith(
        content: Message(content: message),
        date: DateTime.now().toIso8601String(),
        key: key,
        status: MessageStatus.sending,
      ),
    );

    final List<String> data = await _SecureStorage.getMessageKeyList();
    _SecureStorage.setMessageKeyList(data..add(key));

    await _ChatSocket.send(
      ChatOutgoingMessage(
        clientKey: key,
        kind: ChatMessageKind.text,
        content: message,
      ),
      onError: (_) {
        _cubit?.updateMessage(
          _MessageModel.initial.copyWith(
            content: Message(content: message),
            date: DateTime.now().toIso8601String(),
            key: key,
            status: MessageStatus.error,
          ),
        );
      },
    );

    _focusNode.requestFocus();
    _listScrollController.jumpTo(0);
  }

  Future<void> initStorage() async {
    await _ChatSocket.dispose();
    _ChatRuntime.instance.setPeer(widget.peer);
    if (_cubit != null) {
      await _ChatSocket.connect(cubit: _cubit!);
    }
  }

  void initBaseUrl() async {
    _baseUrl = await _SecureStorage.getBaseUrl();
    if (mounted) setState(() {});
  }

  void _updateBottomPadding() {
    final RenderBox? renderBox =
        _bottomAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      if (_bottomPaddingNotifier.value != height) {
        _bottomPaddingNotifier.value = height;
      }
    }
  }

  @override
  void dispose() {
    _ChatSocket.dispose();
    _controller.dispose();
    _voiceController.dispose();
    _connectionSteam?.cancel();
    if (_isInternalCubit) {
      _cubit?.close();
    }
    WidgetsBinding.instance.removeObserver(this);
    _listScrollController.dispose();
    _focusNode.dispose();
    _showEmojiNotifier.dispose();
    _isEmojiModeNotifier.dispose();
    _bottomPaddingNotifier.dispose();
    _showScrollDownNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) return const SizedBox.shrink();

    return BlocProvider.value(
      value: _cubit!,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBodyBehindAppBar: widget.chatAppBarStyle != null,
        backgroundColor: widget.chatDecoration.backgroundColor,
        appBar: widget.chatAppBarStyle != null
            ? _ChatAppBar(style: widget.chatAppBarStyle!, peer: widget.peer)
            : null,
        body: Stack(
          children: [
            // 1. Background Layer
            if (widget.chatDecoration.backgroundImagePng != null)
              Positioned.fill(
                child: Image.asset(
                  widget.chatDecoration.backgroundImagePng!,
                  package: 'messenger_chat',
                  fit: BoxFit.cover,
                ),
              ),
            if (widget.chatDecoration.backgroundImageSvg != null)
              Positioned.fill(
                child: SvgPicture.asset(
                  widget.chatDecoration.backgroundImageSvg!,
                  package: 'messenger_chat',
                  fit: BoxFit.cover,
                  colorFilter: widget.chatDecoration.backgroundSvgColor != null
                      ? ColorFilter.mode(
                          widget.chatDecoration.backgroundSvgColor!,
                          BlendMode.srcIn,
                        )
                      : null,
                ),
              ),

            // 2. Message List Layer
            Positioned.fill(
              child: _MessageList(
                messageStyle: widget.messageStyle,
                bottomPaddingNotifier: _bottomPaddingNotifier,
                hasAppBar: widget.chatAppBarStyle != null,
                listScrollController: _listScrollController,
              ),
            ),

            // Scroll Down Button
            ValueListenableBuilder<double>(
              valueListenable: _bottomPaddingNotifier,
              builder: (context, padding, _) {
                return Positioned(
                  bottom: padding + 16,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _showScrollDownNotifier,
                    builder: (context, show, _) {
                      if (!show) return const SizedBox.shrink();
                      return Center(
                        child: _GeneralEffectsButton(
                          onTap: () => _listScrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn,
                          ),
                          constraints: const BoxConstraints(),
                          borderRadius: BorderRadius.circular(21),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(21),
                              child: _MaybeBlur(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xff1064FF,
                                    ).withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            // 3. Input Layer
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (notification) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateBottomPadding();
                  });
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  child: Column(
                    key: _bottomAreaKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Typing indicator
                      BlocBuilder<ChatCubit, ChatState>(
                        builder: (context, state) {
                          return _AnimatedVisible(
                            visible:
                                state.isTyping && state.typingType != 'voice',
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                bottom: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${state.typingName} typing',
                                    style: widget
                                        .messageStyle.adminMessageTimeTextStyle
                                        .copyWith(fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  _TypingIndicator(
                                    dotColor: widget.messageStyle
                                            .adminMessageTimeTextStyle.color ??
                                        Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Input field
                      ValueListenableBuilder<bool>(
                        valueListenable: _showEmojiNotifier,
                        builder: (context, showEmoji, _) {
                          return ValueListenableBuilder<bool>(
                            valueListenable: _isEmojiModeNotifier,
                            builder: (context, isMode, _) {
                              return _ChatTextField(
                                style: widget.chatTextFieldStyle,
                                listScrollController: _listScrollController,
                                voiceController: _voiceController,
                                focusNode: _focusNode,
                                controller: _controller,
                                config: _cubit!.state.config,
                                isEmojiMode: isMode,
                                onSendMessage: _sendMessage,
                                onEmojiToggled: (isMode, show) {
                                  _isEmojiModeNotifier.value = isMode;
                                  _showEmojiNotifier.value = show;
                                },
                              );
                            },
                          );
                        },
                      ),
                      // Emoji Picker / Keyboard Spacer
                      ValueListenableBuilder<bool>(
                        valueListenable: _showEmojiNotifier,
                        builder: (context, showEmoji, _) {
                          final bottomInset = MediaQuery.viewInsetsOf(
                            context,
                          ).bottom;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: showEmoji
                                ? math.max(300.0, bottomInset)
                                : bottomInset,
                            child: showEmoji
                                ? epf.EmojiPicker(
                                    textEditingController: _controller,
                                    config: epf.Config(
                                      height: 256,
                                      checkPlatformCompatibility: false,
                                      skinToneConfig:
                                          const epf.SkinToneConfig(),
                                      categoryViewConfig:
                                          const epf.CategoryViewConfig(),
                                      bottomActionBarConfig:
                                          const epf.BottomActionBarConfig(
                                        enabled: false,
                                      ),
                                      searchViewConfig:
                                          const epf.SearchViewConfig(),
                                      emojiViewConfig: epf.EmojiViewConfig(
                                        backgroundColor: widget
                                            .chatDecoration.backgroundColor,
                                        columns: 7,
                                        emojiSizeMax:
                                            28 * (Platform.isIOS ? 1.20 : 1.0),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Toast layer
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: _ChatToastNotifier(controller: _chatController),
            ),
          ],
        ),
      ),
    );
  }
}

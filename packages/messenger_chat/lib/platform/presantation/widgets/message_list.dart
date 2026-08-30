part of messenger_chat;

class _MessageList extends StatefulWidget {
  const _MessageList({
    required this.messageStyle,
    required this.listScrollController,
    this.bottomPaddingNotifier,
    this.hasAppBar = false,
  });

  final ChatMessageStyle messageStyle;
  final ScrollController listScrollController;
  final ValueListenable<double>? bottomPaddingNotifier;
  final bool hasAppBar;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  late final FocusNode focusNode;
  List<double> waveformData = [];
  bool isWaveformReady = false;
  late String audioFilePath;
  List<PlatformFile>? paths;
  Float32List? data;
  bool average = false;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<ChatCubit, ChatState>(
    builder: (context, state) => RefreshIndicator(
      notificationPredicate: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          if (scrollNotification.metrics.maxScrollExtent <=
              scrollNotification.metrics.pixels) {
            context.read<ChatCubit>().getMessages(
              page: state.messages.currentPage + 1,
            );
          }
        }

        return false;
      },
      onRefresh: () async {
        return;
      },
      child: state.isLoading
          ? ListView.builder(
              itemCount: 15,
              reverse: true,
              itemBuilder: (context, index) {
                final isAdmin = math.Random().nextBool();

                return Column(
                  children: [
                    _SlideUpFadeTransition(
                      child: _CustomShimmerEffect(
                        isLoading: true,
                        effectType: _ShimmerEffectType.leaf,
                        child: Builder(
                          builder: (context) {
                            final contentType = math.Random().nextBool()
                                ? _ContentType.text
                                : _ContentType.photo;
                            final String content = contentType.isText
                                ? _RandomLoremIpsum.generate()
                                : '';
                            return _ChatBubble(
                              config: state.config,
                              isAdmin: !isAdmin,
                              message: _MessageModel.initial.copyWith(
                                contentType: contentType,
                                content: Message(content: content),
                              ),
                              showDate: false,
                              showSenderName: isAdmin,
                              showPeerAvatar: true,
                              date: '',
                              messageStyle: widget.messageStyle,
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: index == 0 ? 70 : 0),
                  ],
                );
              },
            )
          : ValueListenableBuilder<double>(
              valueListenable:
                  widget.bottomPaddingNotifier ?? ValueNotifier<double>(0.0),
              builder: (context, bottomPadding, _) {
                final topPadding = widget.hasAppBar
                    ? (MediaQuery.of(context).padding.top + 72.0)
                    : 8.0;

                return ListView.builder(
                  controller: widget.listScrollController,
                  reverse: true,
                  padding: EdgeInsets.only(
                    bottom: bottomPadding + 8,
                    top: topPadding,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: state.messages.messages.length,
                  itemBuilder: (context, index) {
                    final message = state.messages.messages[index];
                    final DateTime dateTime =
                        DateTime.tryParse(message.date) ?? DateTime.now();

                    final nextMessage =
                        index + 1 < state.messages.messages.length
                        ? state.messages.messages[index + 1]
                        : null;

                    final showDate = _DateUtility.shouldShowDate(
                      dateTime,
                      DateTime.tryParse(nextMessage?.date ?? ''),
                    );
                    final bool showSenderName =
                        message.isFromPeer &&
                            !(nextMessage?.isFromPeer ?? false) ||
                        !(nextMessage?.senderName == message.senderName);
                    final previousMessage = index - 1 >= 0
                        ? state.messages.messages[index - 1]
                        : null;

                    final isCurrentFromPeer = message.isFromPeer;
                    final isPreviousFromPeer =
                        previousMessage?.isFromPeer ?? false;

                    final showPeerAvatar =
                        isCurrentFromPeer && !isPreviousFromPeer ||
                        message.senderName != previousMessage?.senderName;

                    final date = _DateUtility.getFormattedDateAndMonth(
                      dateTime,
                    );

                    return Column(
                      key: ValueKey(
                        !message.isLocal
                            ? 'msg_id_${message.id}'
                            : 'msg_key_${message.key}',
                      ),
                      children: [
                        _AnimatedVisibleVertical(
                          visible:
                              state.messages.messages.length - 1 == index &&
                              state.isLoadMore &&
                              !state.isLoading &&
                              state.messages.hasNextPage,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: _CircularLoading(
                                  color: widget
                                      .messageStyle
                                      .clientMessageBackgroundColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.zero,
                          child: VisibilityDetector(
                            key: Key('${message.id}'),
                            onVisibilityChanged: (info) {
                              final percentage = info.visibleFraction * 100;

                              if (message.isRead ||
                                  percentage != 100 ||
                                  !message.isFromPeer)
                                return;

                              unawaited(
                                _ChatSocket.markRead(
                                  messageId: message.id,
                                ),
                              );

                              context.read<ChatCubit>().markMessageAsRead(
                                message.id,
                              );
                            },
                            child: _ChatBubble(
                              isAdmin: message.isFromPeer,
                              message: message,
                              config: state.config,
                              showDate: showDate,
                              showSenderName: showSenderName,
                              showPeerAvatar: showPeerAvatar,
                              date: date,
                              messageStyle: widget.messageStyle,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    ),
  );
}

part of messenger_chat;

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.style, required this.peer});

  final ChatAppBarStyle style;

  /// Suhbatdosh - ochiq API orqali beriladi.
  final ChatUser peer;

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 56.0,
    backgroundColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    shadowColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Theme.of(context).brightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      statusBarBrightness: Theme.of(context).brightness,
    ),
    centerTitle: style.centerTitle,
    titleSpacing: 0,
    flexibleSpace: ClipRect(
      child: _MaybeBlur(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(color: _surfaceColor(style.backgroundColor, 0.7)),
      ),
    ),
    title: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: style.profileBackgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              if (style.elevation > 0)
                BoxShadow(
                  color: (style.shadowColor ?? Colors.black).withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: _PeerAvatar(peer: peer, style: style),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                peer.name,
                style: style.titleTextStyle?.copyWith(letterSpacing: -0.5),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              StreamBuilder<TypingStatus>(
                stream: MessengerChat.controller.typingStream,
                builder: (context, typingSnapshot) {
                  if (typingSnapshot.hasData && typingSnapshot.data!.isTyping) {
                    final type = typingSnapshot.data!.type;
                    final name = typingSnapshot.data!.userName;
                    final typingText = switch (type) {
                      'voice' => _AppTexts.typingVoice,
                      'photo' => _AppTexts.typingPhoto,
                      'video' => _AppTexts.typingVideo,
                      'document' => _AppTexts.typingFile,
                      _ => _AppTexts.typing,
                    };
                    return Text(
                      '${name != null ? '$name ' : ''}$typingText',
                      style: (style.labelTextStyle ?? const TextStyle())
                          .copyWith(
                            color: style.typingTextColor,
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                      overflow: TextOverflow.ellipsis,
                    );
                  }
                  return StreamBuilder<ChatConnectionStatus>(
                    stream: MessengerChat.controller.connectionStream,
                    initialData: MessengerChat.controller.connectionStatus,
                    builder: (context, value) {
                      final status =
                          value.data ?? MessengerChat.controller.connectionStatus;
                      final isConnecting =
                          status == ChatConnectionStatus.connecting;

                      // Ulanish tayyor bo'lsa - suhbatdoshning haqiqiy
                      // holatini ko'rsatamiz, aks holda o'z ulanishimizni.
                      if (status == ChatConnectionStatus.connected) {
                        return ValueListenableBuilder<ChatUser?>(
                          valueListenable: _ChatRuntime.instance.peerNotifier,
                          builder: (context, livePeer, __) =>
                              _PeerStatus(peer: livePeer ?? peer, style: style),
                        );
                      }

                      const isConnected = false;

                      return Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? style.onlineColor
                                  : isConnecting
                                  ? Colors.orange
                                  : style.offlineColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isConnected
                                  ? _AppTexts.online
                                  : isConnecting
                                  ? _AppTexts.connecting
                                  : _AppTexts.socketConnectionNot,
                              style:
                                  (style.statusTextStyle ??
                                          style.labelTextStyle ??
                                          const TextStyle())
                                      .copyWith(
                                        fontSize: 11,
                                        color: isConnected
                                            ? style.onlineColor.withOpacity(0.9)
                                            : style.offlineColor.withOpacity(
                                                0.8,
                                              ),
                                      ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    ),
    leading: Container(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
      ),
      child: _GeneralEffectsButton(
        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        // Ilova o'z ishlovchisini bermasa, oddiy orqaga qaytish bajariladi -
        // aks holda tugma jimgina ishlamay turadi.
        onTap: () {
          final handler = style.onBackButton;
          if (handler != null) {
            handler();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        child: Center(
          child: Icon(
            ChatIcons.chevronLeft,
            color: style.backIconSvgColor,
            size: 24,
          ),
        ),
      ),
    ),
  );

  @override
  Size get preferredSize => const Size(double.infinity, 56);
}

/// Suhbatdosh avatari. Rasm bo'lmasa ismning bosh harflari chiziladi.
class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.peer, required this.style});

  final ChatUser peer;
  final ChatAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = peer.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          width: 44,
          height: 44,
          errorWidget: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() => Center(
    child: Text(
      peer.initials,
      style: TextStyle(
        color: style.profileIconColor,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    ),
  );
}


/// Suhbatdoshning holati: onlayn yoki oxirgi ko'rilgan vaqt.
class _PeerStatus extends StatelessWidget {
  const _PeerStatus({required this.peer, required this.style});

  final ChatUser peer;
  final ChatAppBarStyle style;

  @override
  Widget build(BuildContext context) {
    final online = peer.isOnline;
    final color = online ? style.onlineColor : style.offlineColor;

    final text = online
        ? _AppTexts.online
        : peer.lastSeen == null
        ? _AppTexts.offline
        : '${_AppTexts.lastSeen} '
              '${_DateUtility.getFormattedTime(peer.lastSeen!.toIso8601String())}';

    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style:
                (style.statusTextStyle ??
                        style.labelTextStyle ??
                        const TextStyle())
                    .copyWith(fontSize: 11, color: color.withOpacity(0.9)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

part of messenger_chat;

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({
    required this.style,
    required this.peer,
    this.trailing,
    this.avatar,
    this.onTitleTap,
  });

  final ChatAppBarStyle style;

  /// Suhbatdosh - ochiq API orqali beriladi.
  final ChatUser peer;

  /// App-provided trailing widget (e.g. an overflow ⋮ menu).
  final Widget? trailing;

  /// App-provided avatar (e.g. with a story ring). Replaces the default.
  final Widget? avatar;

  /// Called when the peer's name is tapped.
  final VoidCallback? onTitleTap;

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 60.0,
    actions: trailing == null
        ? null
        : [
            trailing!,
            const SizedBox(width: 4),
          ],
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
        // App-provided avatar (with a story ring, its own tap) when given —
        // otherwise the default flat circle.
        avatar ??
            Container(
              width: 44,
              height: 44,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: style.profileBackgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  if (style.elevation > 0)
                    BoxShadow(
                      color: (style.shadowColor ?? Colors.black)
                          .withOpacity(0.1),
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
              GestureDetector(
                onTap: onTitleTap,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  peer.name,
                  style: style.titleTextStyle?.copyWith(letterSpacing: -0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              StreamBuilder<TypingStatus>(
                stream: MessengerChat.controller.typingStream,
                builder: (context, typingSnapshot) {
                  if (typingSnapshot.hasData && typingSnapshot.data!.isTyping) {
                    final type = typingSnapshot.data!.type;
                    final typingText = switch (type) {
                      'voice' => _AppTexts.typingVoice,
                      'photo' => _AppTexts.typingPhoto,
                      'video' => _AppTexts.typingVideo,
                      'document' => _AppTexts.typingFile,
                      _ => _AppTexts.typing,
                    };
                    return Text(
                      typingText,
                      // Upright (not italic), matching the "online" status and
                      // the bottom typing line — italic made it look slanted.
                      style:
                          (style.statusTextStyle ??
                                  style.labelTextStyle ??
                                  const TextStyle())
                              .copyWith(
                                color: style.typingTextColor,
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

                      // Ulanish tayyor bo'lsa - suhbatdoshning haqiqiy holatini
                      // ko'rsatamiz. Ulanayotgan paytda ham suhbatdoshning
                      // ochilishда REST'дан seed qilingan oxirgi holatini
                      // ko'rsatamiz - ekran ochilганда bir zumга "ulanish yo'q"
                      // chaqnab, keyin online bo'lishининг o'rniga. Faqat
                      // haqiqiy uzilish (disconnected/error) ogohlantiradi.
                      if (status == ChatConnectionStatus.connected ||
                          status == ChatConnectionStatus.connecting) {
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
  Size get preferredSize => const Size(double.infinity, 60);
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
      // Fill the whole 44px circle (the parent clips it) — no inner padding /
      // background ring around the photo.
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        width: 44,
        height: 44,
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  // Default "empty" avatar: the app-wide default photo (white circle + the
  // shared profile_photo.png), matching the inbox/type-tab avatars — not the
  // user's initials.
  Widget _placeholder() => Container(
    color: Colors.white,
    alignment: Alignment.center,
    child: Image.asset(
      'assets/images/profile_photo.png',
      package: 'messenger_chat',
      fit: BoxFit.cover,
      width: 44,
      height: 44,
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

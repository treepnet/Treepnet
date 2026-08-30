part of messenger_chat;

class _PeerContent extends StatelessWidget {
  const _PeerContent({
    required this.message,
    required this.messageStyle,
    required this.showSenderName,
    required this.showPeerAvatar,
    required this.config,
  });

  final _MessageModel message;
  final _ConfigModel config;
  final bool showSenderName;
  final bool showPeerAvatar;
  final ChatMessageStyle messageStyle;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPeerAvatar) ...[
            _SlideUpFadeTransition(
              child: Skeleton.leaf(
                child: Container(
                  width: 36,
                  height: 36,
                  clipBehavior: Clip.hardEdge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: messageStyle.adminProfileBackgroundColor,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: _PeerBubbleAvatar(
                    peer: _ChatRuntime.instance.peer,
                    fallbackColor: messageStyle.adminAuthorTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 42),
          switch (message.contentType) {
            (_ContentType.text) => Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 100),
                  child: _TextMessage(
                    message: message,
                    messageStyle: messageStyle,
                    showSenderName: showSenderName,
                  ),
                ),
              ),
            (_ContentType.voice) => config.voiceIsBlock
                ? const SizedBox.shrink()
                : _AudioMessage(
                    showSenderName: showSenderName,
                    message: message,
                    messageStyle: messageStyle,
                  ),
            (_ContentType.video) => config.videoIsBlock
                ? const SizedBox.shrink()
                : _VideoMessage(
                    showSenderName: showSenderName,
                    message: message,
                    messageStyle: messageStyle,
                  ),
            (_ContentType.document) => config.documentIsBlock
                ? const SizedBox.shrink()
                : _FileMessage(
                    message: message,
                    messageStyle: messageStyle,
                    showSenderName: showSenderName,
                  ),
            (_ContentType.photo) => config.photoIsBlock
                ? const SizedBox.shrink()
                : _ImageMessage(
                    message: message,
                    messageStyle: messageStyle,
                    showSenderName: showSenderName,
                  ),
          },
        ],
      );
}

/// Xabar yonidagi suhbatdosh avatari.
///
/// Rasm bo'lsa - o'sha, aks holda ismning bosh harflari. Ilgari bu yerda
/// qat'iy naushnik ikonkasi turardi (CRM operatori uchun).
class _PeerBubbleAvatar extends StatelessWidget {
  const _PeerBubbleAvatar({required this.peer, required this.fallbackColor});

  final ChatUser? peer;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = peer?.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        width: 36,
        height: 36,
        errorWidget: (_, __, ___) => _initials(),
        placeholder: (_, __) => _initials(),
      );
    }
    return _initials();
  }

  Widget _initials() => Center(
    child: Text(
      peer?.initials ?? '?',
      style: TextStyle(
        color: fallbackColor,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  );
}

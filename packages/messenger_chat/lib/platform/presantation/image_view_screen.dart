part of messenger_chat;

class _ImageViewScreen extends StatefulWidget {
  const _ImageViewScreen({required this.image, super.key});

  final String image;

  @override
  State<_ImageViewScreen> createState() => _ImageViewScreenState();
}

class _ImageViewScreenState extends State<_ImageViewScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: widget.image,
            child: Center(
              child: _ChatCachedImage(
                imageUrl: widget.image,
                isViewScreen: true,
                value: 0,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 8,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    ChatIcons.chevronLeft,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

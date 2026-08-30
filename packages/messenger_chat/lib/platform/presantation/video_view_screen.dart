part of messenger_chat;

class _VideoViewScreen extends StatefulWidget {
  const _VideoViewScreen({
    required this.videoUrl,
    required this.imageUrl,
    required this.color,
  });

  final String videoUrl;
  final String imageUrl;
  final Color color;

  @override
  State<_VideoViewScreen> createState() => _VideoViewScreenState();
}

class _VideoViewScreenState extends State<_VideoViewScreen> {
  VideoPlayerController? videoPlayerController;
  FlickManager? flickManager;

  @override
  void initState() {
    super.initState();

    videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    flickManager = FlickManager(
      videoPlayerController:
          videoPlayerController ??
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)),
      autoInitialize: false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Hero(
          tag: widget.videoUrl,
          child: FutureBuilder(
            future: videoPlayerController?.initialize(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  flickManager != null) {
                flickManager!.flickControlManager!.play();

                return OrientationBuilder(
                  builder: (context, orientation) => Center(
                    child: FlickVideoPlayer(
                      flickManager: flickManager!,
                      flickVideoWithControls: FlickVideoWithControls(
                        videoFit: BoxFit.contain,
                        playerLoadingFallback: _loadingVideo(),
                        controls: const _CustomPortraitControls(),
                      ),
                    ),
                  ),
                );
              }

              return _loadingVideo();
            },
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

  Widget _loadingVideo() => Stack(
    children: [
      _ChatCachedImage(
        width: double.infinity,
        height: double.infinity,
        value: 0,
        imageUrl: widget.imageUrl,
      ),

      Center(child: _CircularLoading(color: widget.color)),
    ],
  );

  @override
  void dispose() {
    videoPlayerController?.dispose();
    flickManager?.flickControlManager?.dispose();
    flickManager = null;
    videoPlayerController = null;
    super.dispose();
  }
}

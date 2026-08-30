part of messenger_chat;

class _ChatCachedImage extends StatefulWidget {
  const _ChatCachedImage({
    required this.imageUrl,
    required this.value,
    this.isViewScreen = false,
    this.borderRadius,
    this.width,
    this.height,
  });

  final double value;
  final double? width;
  final double? height;
  final String imageUrl;
  final bool isViewScreen;
  final BorderRadius? borderRadius;

  @override
  State<_ChatCachedImage> createState() => _ChatCachedImageState();
}

class _ChatCachedImageState extends State<_ChatCachedImage> {
  late ImageProvider _imageProvider;

  double? _displayWidth;

  double? _displayHeight;

  final int _randomWidth = 100 + math.Random().nextInt(150);

  final int _randomHeight = 150 + math.Random().nextInt(300);

  @override
  void initState() {
    super.initState();
    _imageProvider = CachedNetworkImageProvider(widget.imageUrl);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.imageUrl.isNotEmpty) _loadImage();
  }

  void _loadImage() {
    _imageProvider = CachedNetworkImageProvider(widget.imageUrl);

    final screenSize = MediaQuery.of(context).size;
    final stream = _imageProvider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          final originalWidth = info.image.width.toDouble();
          final originalHeight = info.image.height.toDouble();

          const maxWidthFactor = 0.7;
          const maxHeightFactor = 0.4;

          final maxWidth = screenSize.width * maxWidthFactor;
          final maxHeight = screenSize.height * maxHeightFactor;

          double displayWidth = originalWidth;
          double displayHeight = originalHeight;

          final widthRatio = displayWidth / maxWidth;
          final heightRatio = displayHeight / maxHeight;

          if (widthRatio > 1 || heightRatio > 1) {
            final maxRatio = widthRatio > heightRatio
                ? widthRatio
                : heightRatio;

            displayWidth /= maxRatio;

            displayHeight /= maxRatio;
          }

          if (mounted) {
            setState(() {
              _displayWidth = displayWidth;
              _displayHeight = displayHeight;
            });

            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() {});
              }
            });
          }
        },
        onError: (error, _) {
          if (mounted) {
            setState(() {
              _displayWidth = 200;
              _displayHeight = 200;
            });
          }
        },
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _ChatCachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _AnimationDurationConstants.animationDuration,

    width: widget.isViewScreen ? null : widget.width ?? _displayWidth,

    height: widget.isViewScreen ? null : widget.height ?? _displayHeight,

    child: ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,

        fit: BoxFit.contain,

        width: widget.isViewScreen ? null : widget.width ?? _displayWidth,

        height: widget.isViewScreen ? null : widget.height ?? _displayHeight,

        placeholder: (context, url) => _CustomShimmerEffect(
          effectType: _ShimmerEffectType.shade,

          isLoading: true,

          child: Container(
            width: widget.width ?? _randomWidth.toDouble(),

            height: widget.height ?? _randomHeight.toDouble(),

            decoration: BoxDecoration(
              color: Colors.grey.shade200.withAlpha((255 * 0.3).round()),

              borderRadius: widget.borderRadius,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: widget.width ?? _displayWidth ?? 200,

          height: widget.height ?? _displayHeight ?? 200,

          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: widget.borderRadius,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.red, size: 40),

                const SizedBox(height: 6),

                Text(
                  _AppTexts.cantDownloadImage,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

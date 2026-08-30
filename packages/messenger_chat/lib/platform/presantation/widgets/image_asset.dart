part of messenger_chat;

class _ChatAssetImage extends StatefulWidget {
  const _ChatAssetImage({required this.imagePath, required this.value, required this.color});

  final double value;
  final String imagePath;
  final Color color;

  @override
  State<_ChatAssetImage> createState() => _ChatAssetImageState();
}

class _ChatAssetImageState extends State<_ChatAssetImage> {
  ImageProvider? _imageProvider;

  Size? _size;

  @override
  void initState() {
    super.initState();
    final file = File(widget.imagePath);
    _imageProvider = FileImage(file);
    getImageSize();
  }

  void getImageSize() async {
    _size = await _ImageSizeDetector.getFileImageSize(context, path: widget.imagePath);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: _AnimationDurationConstants.animationDuration,
    width: _size?.width ?? 200,
    height: _size?.height ?? 300,
    decoration: BoxDecoration(
      image: DecorationImage(image: _imageProvider!, fit: BoxFit.contain),
    ),
  );
}

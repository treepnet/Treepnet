part of messenger_chat;

mixin _ImageSizeDetector {
  static Future<ui.Size> getFileImageSize(
      BuildContext context, {
        required String path,
      }) async {
    try {
      if (path.isEmpty) {
        return const ui.Size(100, 100);
      }

      final file = File(path);
      final exists = file.exists;
      if (!await exists()) {
        return const ui.Size(100, 100);
      }

      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      final screenSize = MediaQuery.of(context).size;
      final image = frame.image;

      final originalWidth = image.width.toDouble();
      final originalHeight = image.height.toDouble();

      const maxWidthFactor = 0.7;
      const maxHeightFactor = 0.4;

      final maxWidth = screenSize.width * maxWidthFactor;
      final maxHeight = screenSize.height * maxHeightFactor;

      double displayWidth = originalWidth;
      double displayHeight = originalHeight;

      final widthRatio = displayWidth / maxWidth;
      final heightRatio = displayHeight / maxHeight;

      if (widthRatio > 1 || heightRatio > 1) {
        final maxRatio = widthRatio > heightRatio ? widthRatio : heightRatio;
        displayWidth /= maxRatio;
        displayHeight /= maxRatio;
      }

      return ui.Size(displayWidth, displayHeight);
    } catch (e) {
      return const ui.Size(100, 100);
    }
  }
}
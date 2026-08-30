part of messenger_chat;

mixin _VideoSizeDetector {
  static Future<ui.Size> getFileVideoSize(BuildContext context, {required String path}) async {
    final controller = VideoPlayerController.file(File(path));

    // metadata yuklanishini kutamiz
    await controller.initialize();

    final screenSize = MediaQuery.of(context).size;

    final originalWidth = controller.value.size.width;
    final originalHeight = controller.value.size.height;

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

    // Controller kerak bo‘lmasa dispose qilib yuboring
    await controller.dispose();

    return ui.Size(displayWidth, displayHeight);
  }
}
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:stories_editor/src/presentation/utils/mixins/safe_set_state_mixin.dart';

class FileImageBG extends StatefulWidget {
  final File? filePath;
  final void Function(Color color1, Color color2) generatedGradient;
  const FileImageBG({
    super.key,
    required this.filePath,
    required this.generatedGradient,
  });

  @override
  State<FileImageBG> createState() => _FileImageBGState();
}

class _FileImageBGState extends State<FileImageBG> with SafeSetStateMixin {
  GlobalKey imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    unawaited(_detectGradient());
  }

  /// The background behind the picture: the average colour of its top and of
  /// its bottom quarter, from a 24px-wide copy. It used to screenshot the
  /// editor, encode that as PNG and decode it again in Dart — twice, on the
  /// main thread, while the editor was opening.
  Future<void> _detectGradient() async {
    final path = widget.filePath?.path;
    if (path == null) return;
    try {
      final codec = await ui.instantiateImageCodec(
        await File(path).readAsBytes(),
        targetWidth: 24,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      codec.dispose();
      if (data == null || width == 0 || height == 0) return;

      Color average(int fromRow, int toRow) {
        var r = 0, g = 0, b = 0, n = 0;
        for (var y = fromRow; y < toRow; y++) {
          for (var x = 0; x < width; x++) {
            final i = (y * width + x) * 4;
            r += data.getUint8(i);
            g += data.getUint8(i + 1);
            b += data.getUint8(i + 2);
            n++;
          }
        }
        if (n == 0) return Colors.grey[350]!;
        return Color.fromARGB(242, r ~/ n, g ~/ n, b ~/ n);
      }

      final band = max(1, height ~/ 4);
      final top = average(0, band);
      final bottom = average(height - band, height);
      if (!mounted) return;
      widget.generatedGradient(top, bottom);
    } catch (_) {
      // Unreadable: the default background stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScreenUtil screenUtil = ScreenUtil();
    return SizedBox(
      height: screenUtil.screenHeight,
      width: screenUtil.screenWidth,
      child: RepaintBoundary(
        child: Center(
          // Whole frame, never cropped. Filling the canvas is done by scaling
          // the item up (see MainView's initial scale), so zooming back out
          // brings the rest of the picture back rather than revealing nothing.
          //
          // Decoded at most 2560px on its longer side — plenty for the 1080px
          // story, zoomed in too — instead of whole (a 50 MP photo is ~200 MB
          // decoded). Still larger than the screen, so it lays out the same.
          child: Image(
            key: imageKey,
            image: ResizeImage(
              FileImage(File(widget.filePath!.path)),
              width: 2560,
              height: 2560,
              policy: ResizeImagePolicy.fit,
            ),
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}

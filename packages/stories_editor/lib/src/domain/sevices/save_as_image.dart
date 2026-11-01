import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:native_exif/native_exif.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stories_editor/src/presentation/utils/image_compress.dart';

/// Save network image to the photo library.
Future<bool> saveAttachmentToGallery(
  String path, {
  int index = 1,
  String relativePath = 'TreepNet',
}) async {
  if (kIsWeb) {
    return false;
  }

  // Generate Telegram-style filename: IMG_YYYYMMDD_HHMMSS_XXX.jpg
  final now = DateTime.now().add(Duration(seconds: index));
  final dateStr = now.year.toString().padLeft(4, '0') +
      now.month.toString().padLeft(2, '0') +
      now.day.toString().padLeft(2, '0');
  final timeStr = now.hour.toString().padLeft(2, '0') +
      now.minute.toString().padLeft(2, '0') +
      now.second.toString().padLeft(2, '0');
  final randomSuffix =
      (Random().nextInt(900) + 100).toString(); // 3-digit random number

  // final originalExtension = file.path.split('.').last.toLowerCase();
  // final extension = originalExtension.isNotEmpty ? originalExtension : 'jpg';
  final title = 'IMG_${dateStr}_${timeStr}_$randomSuffix';

  // 1) Write EXIF capture time to now
  final exif = await Exif.fromPath(path);
  String exifNow(String k) {
    // EXIF expects "YYYY:MM:DD HH:MM:SS"
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '$y:$m:$d $h:$mi:$s';
  }

  await exif.writeAttributes({
    'DateTimeOriginal': exifNow('DateTimeOriginal'),
    'DateTimeDigitized': exifNow('DateTimeDigitized'),
    'DateTime': exifNow('DateTime'),
  });
  await exif.close();

  final data = await File(path).readAsBytes();

  // 2) Save by path so the system picks up EXIF and album
  await Gal.putImageBytes(data, name: title, album: relativePath);
  return true;
}

Future<dynamic> takePicture({
  required GlobalKey contentKey,
  required BuildContext context,
  required bool saveToGallery,
}) async {
  try {
    final boundary =
        contentKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return false;

    // 1080px wide, the size a story is uploaded at, rather than 3x the screen
    // (1320x2868 on a large iPhone): that was slow to encode as PNG and got
    // shrunk again anyway. Never more than the old 3x.
    final width = boundary.size.width;
    final pixelRatio = width > 0 ? min(3.0, 1080 / width) : 3.0;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final pngBytes = byteData?.buffer.asUint8List();
    if (pngBytes == null) return false;
    // A story stays lossless here: the upload queue makes its one JPEG
    // (1080px, quality 82). It used to be re-encoded here first as well, so
    // it lost quality twice. A copy for the gallery is still a JPEG.
    final compressedBytes = saveToGallery
        ? await ImageCompress.compressByte(pngBytes)
        : pngBytes;

    /// create file
    // In the temp folder: the upload queue copies it straight away (and then
    // deletes this one), a gallery save reads it once. It used to go to the
    // Documents folder, where every story left a 0.5-2 MB file for good —
    // backed up to iCloud on iOS.
    final dir = (await getTemporaryDirectory()).path;
    final imagePath = '$dir/${DateTime.now()}.png';
    final capturedFile = File(imagePath);
    await capturedFile.writeAsBytes(compressedBytes!);

    if (saveToGallery) {
      final result = await saveAttachmentToGallery(imagePath);
      try {
        await capturedFile.delete();
      } catch (_) {}
      return result;
    } else {
      return imagePath;
    }
  } catch (e) {
    return false;
  }
}

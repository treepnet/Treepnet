import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// {@template image_compress}
/// Allows compressing image files and bytes.
/// {@endtemplate}
class ImageCompress {
  const ImageCompress._();

  /// Compress image byte.
  static Future<Uint8List> compressByte(Uint8List file) async {
    if (file.lengthInBytes <= 200000) return file;
    return FlutterImageCompress.compressWithList(
      file,
      // Cap the resolution. A phone camera shot is often 4000px+ on its long
      // edge; uploading that full size is what made sharing a post slow, and
      // no screen in the app ever shows more than a fraction of it. Scaling
      // to ~1440 keeps it sharp while cutting several MB down to a few
      // hundred KB. (The previous rule did the opposite — the biggest files
      // were compressed the *least*, at quality 90 and full resolution.)
      minWidth: 1440,
      minHeight: 1440,
      quality: 80,
    );
  }

  /// Compresses file bytes and writes into file.
  static Future<File> compressByteAndWriteFile(
    Uint8List file, {
    required Directory tempDir,
    required String fileExtension,
  }) async {
    final bytes = await compute(compressByte, file);
    final newFile = await compute(
      (list) => writeToFile(
        list[0] as ByteData,
        tempDir: list[1] as Directory,
        fileExtension: list[2] as String,
      ),
      [ByteData.view(bytes.buffer), tempDir, fileExtension],
    );
    return newFile;
  }

  /// Writes to the file `ByteData` with [fileExtension].
  static Future<File> writeToFile(
    ByteData data, {
    required Directory tempDir,
    required String fileExtension,
  }) async {
    final buffer = data.buffer;
    final tempPath = tempDir.path;
    final filePath = '$tempPath/${DateTime.now()}.$fileExtension';
    return File(filePath).writeAsBytes(
      buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  /// Compress image file.
  static Future<XFile?> compressFile(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp('.png|.jp'));
    if (lastIndex == -1) return null;
    final splitted = filePath.substring(0, lastIndex);
    final outPath = '${splitted}_out${filePath.substring(lastIndex)}';

    if (lastIndex == filePath.lastIndexOf(RegExp('.png'))) {
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: 1000,
        minHeight: 1000,
        quality: 50,
        format: CompressFormat.png,
      );
      return compressedImage;
    } else {
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        minWidth: 1000,
        minHeight: 1000,
        quality: 50,
      );
      return compressedImage;
    }
  }
}

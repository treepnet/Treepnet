import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// {@template image_compress}
/// Allows compressing image files and bytes.
/// {@endtemplate}
class ImageCompress {
  const ImageCompress._();

  /// Compress image byte.
  static Future<Uint8List?> compressByte(Uint8List? file) async {
    if (file == null) return null;
    if (file.lengthInBytes > 200000) {
      final result = await FlutterImageCompress.compressWithList(
        file,
        quality: file.lengthInBytes > 4000000 ? 90 : 72,
      );
      return result;
    } else {
      return file;
    }
  }
}

import 'dart:typed_data';

import 'package:blurhash/blurhash.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// {@template blur_hash_plus}
/// A package that manages blur hash.
/// {@endtemplate}
class BlurHashPlus {
  const BlurHashPlus._();

  /// Returns a [String] containing the blur hash of the image.
  ///
  /// Worked out from a copy about 64 px across. The plugin encodes on the
  /// platform's main thread, looping over every pixel twelve times: over a
  /// 1440 px photo that took seconds per photo, freezing the app while a post
  /// went out (on Android, an "isn't responding" dialog). A 4×3 blur hash only
  /// keeps the broad colours, so the small copy gives the same one, in
  /// milliseconds. The downscale runs off the main thread.
  static Future<String> blurHashEncode(Uint8List bytes) async {
    final small = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 64,
      minHeight: 64,
      quality: 90,
    );
    return BlurHash.encode(small, 4, 3);
  }
}

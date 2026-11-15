import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// {@template image_compress}
/// Allows compressing image files and bytes.
/// {@endtemplate}
class ImageCompress {
  const ImageCompress._();

  /// Re-encodes a post photo as a JPEG of at most ~1440px, whatever its size
  /// or kind. Small files used to go up untouched, with their EXIF — the GPS
  /// spot where the photo was taken among it — and their rotation unapplied.
  /// The encoder writes no metadata and turns the picture upright.
  static Future<Uint8List> compressByte(Uint8List file) async {
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

  /// A small JPEG of a post photo for the grids (profile, saved posts, map,
  /// timeline): its shorter side scaled down to 480px, enough to fill a tile a
  /// third of a phone screen wide even on the widest phones. Tiles used to
  /// download the full photo, roughly ten times the size.
  static Future<Uint8List> compressThumbnail(Uint8List bytes) =>
      FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 480,
        minHeight: 480,
        quality: 75,
      );

  /// Re-encodes a finished story for upload as a JPEG sized for a phone screen.
  ///
  /// The story editor exports a lossless PNG captured at 3x scale, and
  /// [compressFile] keeps `.png` files as PNG, where `quality` has no effect.
  /// Stories were therefore uploaded at 2–4.5 MB each, and viewers on mobile
  /// data saw a black screen for seconds before each one appeared. A story is
  /// an opaque full-screen picture, so JPEG loses nothing visible and the file
  /// shrinks roughly tenfold. Width 1080 is the widest common phone screen.
  static Future<XFile?> compressStory(File file) {
    final filePath = file.absolute.path;
    final dot = filePath.lastIndexOf('.');
    final base = dot == -1 ? filePath : filePath.substring(0, dot);
    return FlutterImageCompress.compressAndGetFile(
      filePath,
      '${base}_story.jpg',
      minWidth: 1080,
      minHeight: 1920,
      quality: 82,
    );
  }

  /// Re-encodes a picked avatar as a JPEG of at most 512px on its shorter
  /// side, whatever it came as. The old path kept PNGs as PNG and passed HEIC
  /// (iPhone photos) through untouched — which Android may not display — at
  /// up to 1000px, for a picture shown at 40–80px in lists.
  static Future<XFile?> compressAvatar(File file) {
    final filePath = file.absolute.path;
    final dot = filePath.lastIndexOf('.');
    final base = dot == -1 ? filePath : filePath.substring(0, dot);
    return FlutterImageCompress.compressAndGetFile(
      filePath,
      '${base}_avatar.jpg',
      minWidth: 512,
      minHeight: 512,
      quality: 80,
    );
  }
}

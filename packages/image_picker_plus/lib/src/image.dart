import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker_plus/image_picker_plus.dart';

/// One gallery tile: the photo's thumbnail bytes, drawn straight from memory.
///
/// It used `CachedMemoryImage` keyed by the bytes' LENGTH only, which wrote
/// every tile to the app's shared disk cache: two photos whose thumbnails
/// came out the same size showed the same picture (for 30 days), and each
/// visit pushed avatars and story images out of that cache (200 files).
/// The thumbnails are small (200 or 350 px), so decoding them as they are
/// costs little; they stay in Flutter's in-memory image cache only.
class MemoryImageDisplay extends StatelessWidget {
  const MemoryImageDisplay({
    required this.imageBytes,
    required this.appTheme,
    super.key,
  });
  final Uint8List imageBytes;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: appTheme.shimmerBaseColor,
      child: Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => buildError(),
      ),
    );
  }

  SizedBox buildError() {
    return SizedBox(
      width: double.infinity,
      child: Icon(
        Icons.warning_amber_rounded,
        color: appTheme.onSurfaceColor,
      ),
    );
  }
}

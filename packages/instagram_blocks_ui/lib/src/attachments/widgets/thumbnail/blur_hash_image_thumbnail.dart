import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:instagram_blocks_ui/src/widgets/widgets.dart';
import 'package:octo_image/octo_image.dart';

/// A network image that decodes at a capped width and keeps its shape.
///
/// [decodeWidth] is a memory budget, not a layout size — the widget always
/// fills whatever box its parent gives it, applying [fit].
class BlurHashImageThumbnail extends StatefulWidget {
  const BlurHashImageThumbnail({
    required this.url,
    this.decodeWidth,
    this.fit = BoxFit.cover,
    super.key,
    this.id,
    this.blurHash,
  });

  final String url;
  final String? blurHash;
  final String? id;

  /// Largest width to decode to, in physical pixels. Height follows from the
  /// image's own proportions.
  final int? decodeWidth;
  final BoxFit? fit;

  @override
  State<BlurHashImageThumbnail> createState() => _BlurHashImageThumbnailState();
}

class _BlurHashImageThumbnailState extends State<BlurHashImageThumbnail> {
  late Key _key = ValueKey(widget.id ?? widget.url);

  void _resetKey() {
    setState(() => _key = ValueKey(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return OctoImage.fromSet(
      key: _key,
      fit: widget.fit,
      // Width only. Handing the decoder BOTH dimensions resizes the bitmap to
      // exactly that box instead of scaling it, and because the width was
      // derived from devicePixelRatio the same photo came out a different
      // shape on every phone — a 1:1 bitmap on a 3x screen, 2:3 on a 2x one.
      memCacheWidth: widget.decodeWidth,
      image: widget.url.startsWith('file://')
          ? FileImage(File(Uri.parse(widget.url).toFilePath())) as ImageProvider
          : CachedNetworkImageProvider(
              widget.url,
              maxWidth: 1080,
              maxHeight: 1080,
              cacheKey: widget.id == null ? widget.url : '${widget.id}/${widget.url}',
            ),
      // No size given: the placeholder fills the same box the image will, so
      // nothing jumps when it swaps in.
      octoSet: OctoBlurHashPlaceholder(
        blurHash: widget.blurHash,
        fit: widget.fit,
        onImageRefresh: _resetKey,
      ),
    );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:instagram_blocks_ui/src/widgets/widgets.dart';
import 'package:octo_image/octo_image.dart';

/// Disk cache for post photos: up to 1000 of them, kept for 30 days.
///
/// The default cache holds 200 files, and post photos used to take two places
/// each (see [BlurHashImageThumbnail]), so scrolling back through the feed
/// re-downloaded them.
final postImageCacheManager = CacheManager(
  Config(
    'treepnetPostImages',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 1000,
  ),
);

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
    this.previewUrl,
  });

  final String url;
  final String? blurHash;
  final String? id;

  /// A small copy of the same photo, shown over the blur hash until [url]
  /// has loaded — a post photo's 480 px thumbnail, which a grid has usually
  /// fetched already. Only the blur's colours showed while a full photo
  /// (300-500 KB) came in, for each page of a many-photo post.
  final String? previewUrl;

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
      // The photo is there at once under its placeholder, which fades out on
      // top. Both used to fade at the same time (the photo in, the
      // placeholder out), and half-way through each let the dark background
      // through: the picture dimmed for a moment as it loaded.
      fadeInDuration: Duration.zero,
      fadeOutDuration: const Duration(milliseconds: 250),
      // Width only. Handing the decoder BOTH dimensions resizes the bitmap to
      // exactly that box instead of scaling it, and because the width was
      // derived from devicePixelRatio the same photo came out a different
      // shape on every phone — a 1:1 bitmap on a 3x screen, 2:3 on a 2x one.
      memCacheWidth: widget.decodeWidth,
      image: widget.url.startsWith('file://')
          ? FileImage(File(Uri.parse(widget.url).toFilePath())) as ImageProvider
          // No maxWidth / maxHeight: they made the cache decode each photo,
          // re-encode it as a PNG (bigger than the JPEG we upload, which is
          // already at most 1440 px) and store that as a second file.
          // [decodeWidth] already bounds the memory used.
          : CachedNetworkImageProvider(
              widget.url,
              cacheManager: postImageCacheManager,
              // The URL alone: a file never changes under its URL. Keyed by
              // id as well, the feed card (media id) and the post's preview
              // (post id) each downloaded and stored the same photo.
              cacheKey: widget.url,
            ),
      // No size given: the placeholder fills the same box the image will, so
      // nothing jumps when it swaps in.
      octoSet: _withPreview(
        OctoBlurHashPlaceholder(
          blurHash: widget.blurHash,
          fit: widget.fit,
          onImageRefresh: _resetKey,
        ),
      ),
    );
  }

  /// [blur], with [BlurHashImageThumbnail.previewUrl] over its blur while the
  /// photo loads (the blur alone shows until the preview is there, or if it
  /// can't be had).
  OctoSet _withPreview(OctoSet blur) {
    final preview = widget.previewUrl;
    if (preview == null || preview.isEmpty || preview == widget.url) {
      return blur;
    }
    return OctoSet(
      placeholderBuilder: (context) => Stack(
        fit: StackFit.expand,
        children: [
          blur.placeholderBuilder!(context),
          Image(
            image: ResizeImage(
              CachedNetworkImageProvider(
                preview,
                cacheManager: postImageCacheManager,
                cacheKey: preview,
              ),
              width: 480,
              policy: ResizeImagePolicy.fit,
            ),
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      errorBuilder: blur.errorBuilder,
    );
  }
}

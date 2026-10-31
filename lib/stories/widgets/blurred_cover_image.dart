import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A story cover as the grid shows it: blurred, and tiny.
///
/// The grid used to decode each cover at 600px and blur it live with an
/// `ImageFiltered`, which re-ran a large blur for every card on every frame
/// while scrolling. This decodes a small copy, blurs it once and keeps the
/// ~5 KB result in the image cache. Stretched back over the card it looks the
/// same, since the blur leaves nothing finer than a few pixels anyway.
///
/// The photo itself is still fetched whole through the shared disk cache, so
/// opening the story right after shows it at once.
@immutable
class BlurredCoverImage extends ImageProvider<BlurredCoverImage> {
  const BlurredCoverImage._(
    this.url, {
    required this.width,
    required this.height,
    required this.sigma,
  });

  /// The cover for a card of [card] size, looking like a live blur of
  /// [blurSigma] over it — both in logical pixels.
  factory BlurredCoverImage.forCard(
    String url, {
    required Size card,
    required double blurSigma,
  }) {
    const width = _outputWidth;
    final height = max(1, (width * card.height / card.width).round());
    // The same blur, scaled down with the picture.
    final sigma = (blurSigma * width / card.width * 100).round() / 100;
    return BlurredCoverImage._(url, width: width, height: height, sigma: sigma);
  }

  static const _outputWidth = 32;

  /// What gets decoded: enough to crop a card's shape out of a portrait or a
  /// landscape photo without going below [_outputWidth].
  static const _decodeBox = 64;

  final String url;

  /// The blurred result, in pixels — the card's shape, [_outputWidth] wide.
  final int width;
  final int height;

  /// Blur sigma in the result's pixels.
  final double sigma;

  @override
  Future<BlurredCoverImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BlurredCoverImage>(this);

  @override
  ImageStreamCompleter loadImage(
    BlurredCoverImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    key._load(),
    informationCollector: () => [
      DiagnosticsProperty<ImageProvider>('Image provider', this),
    ],
  );

  Future<ImageInfo> _load() async {
    final source = await _firstFrame(
      ResizeImage(
        CachedNetworkImageProvider(url),
        width: _decodeBox,
        height: _decodeBox,
        policy: ResizeImagePolicy.fit,
      ),
    );
    try {
      return ImageInfo(
        image: await blurCover(
          source.image,
          width: width,
          height: height,
          sigma: sigma,
        ),
      );
    } finally {
      source.dispose();
    }
  }

  /// [source] cropped to the result's shape the way `BoxFit.cover` crops it,
  /// then blurred. Past the edge counts as transparent (decal), so the edges
  /// fade just as the live blur's did.
  @visibleForTesting
  static Future<ui.Image> blurCover(
    ui.Image source, {
    required int width,
    required int height,
    required double sigma,
  }) async {
    final sourceWidth = source.width.toDouble();
    final sourceHeight = source.height.toDouble();
    final scale = max(width / sourceWidth, height / sourceHeight);
    final cropWidth = width / scale;
    final cropHeight = height / scale;
    final crop = Rect.fromLTWH(
      (sourceWidth - cropWidth) / 2,
      (sourceHeight - cropHeight) / 2,
      cropWidth,
      cropHeight,
    );
    final output = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

    final recorder = ui.PictureRecorder();
    Canvas(recorder, output)
      ..saveLayer(
        output,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
      )
      ..drawImageRect(
        source,
        crop,
        output,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore();
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  /// The first frame [provider] delivers. The caller owns it and disposes it.
  static Future<ImageInfo> _firstFrame(ImageProvider provider) {
    final completer = Completer<ImageInfo>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        completer.complete(info);
      },
      onError: (error, stackTrace) {
        stream.removeListener(listener);
        completer.completeError(error, stackTrace);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  @override
  bool operator ==(Object other) =>
      other is BlurredCoverImage &&
      other.url == url &&
      other.width == width &&
      other.height == height &&
      other.sigma == sigma;

  @override
  int get hashCode => Object.hash(url, width, height, sigma);

  // No url: story links carry an access token, and this lands in error logs.
  @override
  String toString() =>
      '${objectRuntimeType(this, 'BlurredCoverImage')}'
      '(${width}x$height, sigma: $sigma)';
}

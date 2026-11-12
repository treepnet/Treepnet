import 'dart:ui' as ui;

/// A crop of one photo, as the preview (CustomCrop) gives it: [area] is the
/// kept part of the image in 0–1 coordinates, [scale] how far it was zoomed
/// (it sets the sample size before cropping).
class PhotoCrop {
  const PhotoCrop({required this.scale, required this.area});

  final double scale;
  final ui.Rect area;
}

class _SavedCrop {
  const _SavedCrop(this.crop, this.aspect);

  final PhotoCrop crop;
  final double aspect;
}

/// The crops of the photos picked for one post, each kept under its own photo
/// (file path) with the frame shape it was made for.
///
/// They used to sit in lists by position in the selection, filled with
/// whatever the preview showed at that moment: taking a photo out of the
/// selection, or tapping quickly, put one photo's crop on another (a square
/// crop of a landscape photo on a portrait one came out a tall strip), and a
/// photo whose preview hadn't loaded yet went out uncropped.
class PhotoCrops {
  final Map<String, _SavedCrop> _byPath = {};

  /// Remembers [crop] of the photo at [path], made in a frame of [aspect]
  /// (width / height).
  void save(String path, PhotoCrop crop, {required double aspect}) =>
      _byPath[path] = _SavedCrop(crop, aspect);

  /// Forgets the photo at [path] (taken out of the selection).
  void remove(String path) => _byPath.remove(path);

  void clear() => _byPath.clear();

  /// The saved crop of [path] for a frame of [aspect], or null when there is
  /// none (never shown long enough to load) or it was made for the other
  /// frame shape (square vs 4:5): those use [centered] instead.
  PhotoCrop? of(String path, {required double aspect}) {
    final saved = _byPath[path];
    if (saved == null || (saved.aspect - aspect).abs() > 0.001) return null;
    return saved.crop;
  }

  /// The middle of an image of [width]×[height] in a frame of [aspect]: what
  /// the preview starts with before it is moved or zoomed.
  static PhotoCrop centered({
    required int width,
    required int height,
    required double aspect,
  }) {
    final ratio = width / height;
    if (ratio > aspect) {
      final w = aspect / ratio;
      return PhotoCrop(scale: 1, area: ui.Rect.fromLTWH((1 - w) / 2, 0, w, 1));
    }
    final h = ratio / aspect;
    return PhotoCrop(scale: 1, area: ui.Rect.fromLTWH(0, (1 - h) / 2, 1, h));
  }

  /// [centered] for the photo at [path], measured from a small decode (which
  /// applies the photo's rotation, as the preview does). Null if it can't be
  /// read.
  static Future<PhotoCrop?> centeredOf(
    String path, {
    required double aspect,
  }) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(path);
      final codec = await ui.instantiateImageCodecFromBuffer(
        buffer,
        targetWidth: 64,
      );
      final frame = await codec.getNextFrame();
      final crop = centered(
        width: frame.image.width,
        height: frame.image.height,
        aspect: aspect,
      );
      frame.image.dispose();
      codec.dispose();
      return crop;
    } catch (_) {
      return null;
    }
  }
}

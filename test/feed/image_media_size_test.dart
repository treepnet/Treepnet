import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  group('ImageMedia size', () {
    test('a recorded size comes back from the post JSON', () {
      final media = ImageMedia.fromJson(const {
        'media_id': 'm1',
        'url': 'https://example.com/a.jpg',
        'type': ImageMedia.identifier,
        'width': 1080,
        'height': 1350,
      });
      expect(media.width, 1080);
      expect(media.height, 1350);
      expect(media.aspectRatio, closeTo(0.8, 1e-9));
      expect(media.toJson()['width'], 1080);
    });

    test('older posts have no size (and no ratio)', () {
      final media = ImageMedia.fromJson(const {
        'media_id': 'm1',
        'url': 'https://example.com/a.jpg',
        'type': ImageMedia.identifier,
      });
      expect(media.aspectRatio, isNull);
      expect(media.toJson().containsKey('width'), isFalse);
    });

    test('a size stored as a double still reads', () {
      final media = ImageMedia.fromJson(const {
        'media_id': 'm1',
        'url': 'https://example.com/a.jpg',
        'width': 1000.0,
        'height': 1000.0,
      });
      expect(media.aspectRatio, 1);
    });
  });
}

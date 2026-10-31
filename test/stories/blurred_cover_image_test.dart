import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/stories/stories.dart';

/// A portrait picture: dark all over, with a white bar across the middle.
Future<ui.Image> _portrait() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 36, 64),
      Paint()..color = const Color(0xFF000000),
    )
    ..drawRect(
      const Rect.fromLTWH(0, 28, 36, 8),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  return recorder.endRecording().toImage(36, 64);
}

Future<List<int>> _pixel(ui.Image image, int x, int y) async {
  final data = (await image.toByteData())!;
  final i = (y * image.width + x) * 4;
  return [for (var c = 0; c < 4; c++) data.getUint8(i + c)];
}

void main() {
  test('sized to the card, blur scaled down with it', () {
    final cover = BlurredCoverImage.forCard(
      'https://example.com/s.jpg',
      card: const Size(160, 204),
      blurSigma: 14,
    );
    expect(cover.width, 32);
    expect(cover.height, 41);
    expect(cover.sigma, 2.8);
    // Same card, same cache entry.
    expect(
      cover,
      BlurredCoverImage.forCard(
        'https://example.com/s.jpg',
        card: const Size(160, 204),
        blurSigma: 14,
      ),
    );
    expect(cover.toString(), isNot(contains('example.com')));
  });

  testWidgets('crops to the card, blurs, and fades out at the edges', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = await _portrait();
      final out = await BlurredCoverImage.blurCover(
        source,
        width: 32,
        height: 41,
        sigma: 3,
      );
      expect([out.width, out.height], [32, 41]);

      final centre = await _pixel(out, 16, 20);
      final corner = await _pixel(out, 0, 0);
      // The bar is softened, not gone, and not still pure white.
      expect(centre[0], inInclusiveRange(60, 250));
      expect(centre[3], 255);
      // Decal: the corner is partly transparent.
      expect(corner[3], lessThan(200));
    });
  });
}

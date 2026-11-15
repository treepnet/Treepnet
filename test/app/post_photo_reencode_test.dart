import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

/// Records what the photo encoder was asked to do.
class _Encoder extends Fake implements FlutterImageCompressPlatform {
  final asked = <({int bytes, CompressFormat format, bool keepExif})>[];

  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    asked.add((bytes: image.length, format: format, keepExif: keepExif));
    return Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);
  }
}

void main() {
  late _Encoder encoder;
  late FlutterImageCompressPlatform real;

  setUp(() {
    real = FlutterImageCompressPlatform.instance;
    encoder = _Encoder();
    FlutterImageCompressPlatform.instance = encoder;
  });

  tearDown(() => FlutterImageCompressPlatform.instance = real);

  test('a small photo is re-encoded too: no EXIF (GPS) reaches the server',
      () async {
    // Up to 200 KB used to go up untouched, with the place it was taken.
    final small = Uint8List(50 * 1024);

    final out = await ImageCompress.compressByte(small);

    expect(encoder.asked, hasLength(1));
    expect(encoder.asked.single.bytes, small.length);
    expect(encoder.asked.single.keepExif, isFalse);
    expect(encoder.asked.single.format, CompressFormat.jpeg);
    expect(out, isNot(same(small)));
  });

  test('a big photo is re-encoded the same way', () async {
    await ImageCompress.compressByte(Uint8List(3 * 1024 * 1024));

    expect(encoder.asked.single.keepExif, isFalse);
    expect(encoder.asked.single.format, CompressFormat.jpeg);
  });
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/src/photo_crops.dart';

Matcher _rect(double l, double t, double w, double h) => isA<Rect>()
    .having((r) => r.left, 'left', closeTo(l, 1e-9))
    .having((r) => r.top, 'top', closeTo(t, 1e-9))
    .having((r) => r.width, 'width', closeTo(w, 1e-9))
    .having((r) => r.height, 'height', closeTo(h, 1e-9));

void main() {
  group('PhotoCrops', () {
    const a = PhotoCrop(scale: 1.5, area: Rect.fromLTWH(0.1, 0.2, 0.5, 0.5));
    const b = PhotoCrop(scale: 1, area: Rect.fromLTWH(0, 0, 0.8, 1));

    test('each photo keeps its own crop, whatever the order of selection', () {
      final crops = PhotoCrops()
        ..save('A', a, aspect: 1)
        ..save('C', b, aspect: 1);
      // B was taken out of the selection: A and C are untouched by it.
      crops.remove('B');
      expect(crops.of('A', aspect: 1), same(a));
      expect(crops.of('C', aspect: 1), same(b));
      expect(crops.of('B', aspect: 1), isNull);
    });

    test('a crop made for the other frame shape is not used', () {
      final crops = PhotoCrops()..save('A', a, aspect: 1);
      expect(crops.of('A', aspect: 4 / 5), isNull);
      expect(crops.of('A', aspect: 1), same(a));
    });

    test('remove and clear forget crops', () {
      final crops = PhotoCrops()
        ..save('A', a, aspect: 1)
        ..save('B', b, aspect: 1)
        ..remove('A');
      expect(crops.of('A', aspect: 1), isNull);
      crops.clear();
      expect(crops.of('B', aspect: 1), isNull);
    });
  });

  group('PhotoCrops.centered', () {
    test('landscape in a square: the middle, full height', () {
      final crop = PhotoCrops.centered(width: 4000, height: 3000, aspect: 1);
      expect(crop.area, _rect(0.125, 0, 0.75, 1));
      expect(crop.scale, 1);
    });

    test('portrait in 4:5: the middle, full width', () {
      final crop = PhotoCrops.centered(
        width: 3000,
        height: 4000,
        aspect: 4 / 5,
      );
      expect(crop.area, _rect(0, 0.03125, 1, 0.9375));
    });

    test('already the frame shape: the whole photo', () {
      final crop = PhotoCrops.centered(width: 800, height: 1000, aspect: 0.8);
      expect(crop.area, _rect(0, 0, 1, 1));
    });

    testWidgets('measured from the file itself', (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 200, 100),
          Paint()..color = const Color(0xFF336699),
        );
        final image = await recorder.endRecording().toImage(200, 100);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = await Directory.systemTemp.createTemp('crop');
        final file = File('${dir.path}/wide.png');
        await file.writeAsBytes(png!.buffer.asUint8List());

        final crop = await PhotoCrops.centeredOf(file.path, aspect: 1);
        expect(crop!.area, _rect(0.25, 0, 0.5, 1));
        expect(
          await PhotoCrops.centeredOf('${dir.path}/missing.png', aspect: 1),
          isNull,
        );
        await dir.delete(recursive: true);
      });
    });
  });
}

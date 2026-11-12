import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/src/custom_crop.dart';

/// A 1200×900 PNG on disk.
Future<File> _photo() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1200, 900),
    Paint()..color = const Color(0xFF557799),
  );
  final image = await recorder.endRecording().toImage(1200, 900);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final dir = await Directory.systemTemp.createTemp('crop_preview');
  final file = File('${dir.path}/photo.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file;
}

/// The crop the preview gives for [file] when the screen is [screenWidth]
/// logical pixels wide (which sets how large the photo is decoded).
Future<Rect?> _cropWithScreen(
  WidgetTester tester,
  File file,
  double screenWidth,
) async {
  final key = GlobalKey<CustomCropState>();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: Size(screenWidth, 800)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: CustomCrop(key: key, image: file, aspectRatio: 1),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 20 && key.currentState?.cropOf(file) == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  return key.currentState?.cropOf(file)?.area;
}

void main() {
  testWidgets('the crop is the same whatever size the preview decodes at', (
    tester,
  ) async {
    final file = (await tester.runAsync(_photo))!;
    // 100 px wide screen: decoded to fit 200 px (well under the photo).
    final small = await _cropWithScreen(tester, file, 100);
    // 1000 px wide: 2000 px box, so the photo decodes in full.
    final full = await _cropWithScreen(tester, file, 1000);
    expect(small, isNotNull);
    expect(full, isNotNull);
    expect(small!.left, closeTo(full!.left, 1e-6));
    expect(small.top, closeTo(full.top, 1e-6));
    expect(small.width, closeTo(full.width, 1e-6));
    expect(small.height, closeTo(full.height, 1e-6));
    // A square crop of a 4:3 photo: its middle, full height.
    expect(full.width, closeTo(0.75, 1e-6));
    expect(full.height, closeTo(1, 1e-6));
    await tester.runAsync(() => file.parent.delete(recursive: true));
  });
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/image.dart';

/// Distinct bytes of one length: what used to share a cache entry.
Uint8List _bytes(int fill) => Uint8List.fromList(List.filled(64, fill));

void main() {
  testWidgets('two thumbnails of the same size each show their own bytes', (
    tester,
  ) async {
    final a = _bytes(1);
    final b = _bytes(2);
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            Expanded(
              child: MemoryImageDisplay(imageBytes: a, appTheme: AppTheme()),
            ),
            Expanded(
              child: MemoryImageDisplay(imageBytes: b, appTheme: AppTheme()),
            ),
          ],
        ),
      ),
    );
    final shown = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as MemoryImage).bytes)
        .toList();
    expect(shown, [same(a), same(b)]);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_plus/image_picker_plus.dart';
import 'package:image_picker_plus/src/multi_selection_mode.dart';

/// The round badge in each grid photo's corner while picking several.
void main() {
  final a = File('/photos/a.jpg');
  final b = File('/photos/b.jpg');

  Finder circle() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool multi,
    required File? image,
    required List<File> picked,
    VoidCallback? onTileTap,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.square(
          dimension: 120,
          child: Stack(
            children: [
              // The tile's photo, under the badge (as the grid lays it).
              Positioned.fill(
                child: GestureDetector(
                  onTap: onTileTap,
                  child: const ColoredBox(color: Colors.grey),
                ),
              ),
              MultiSelectionMode(
                appTheme: const AppTheme(),
                image: image,
                multiSelectionMode: ValueNotifier(multi),
                imageSelected: image != null && picked.contains(image),
                multiSelectedImage: picked,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('a photo not opened yet shows an empty badge', (tester) async {
    // The grid has no file for a tile until it is tapped: it showed no
    // badge at all, so most tiles had none.
    await pump(tester, multi: true, image: null, picked: [a]);
    expect(circle(), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('a picked photo shows its place in the selection', (
    tester,
  ) async {
    await pump(tester, multi: true, image: b, picked: [a, b]);
    expect(circle(), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('no badge when picking one photo', (tester) async {
    await pump(tester, multi: false, image: a, picked: const []);
    expect(circle(), findsNothing);
  });

  testWidgets('a tap on the badge picks the photo', (tester) async {
    var taps = 0;
    await pump(
      tester,
      multi: true,
      image: null,
      picked: const [],
      onTileTap: () => taps++,
    );
    await tester.tap(circle());
    expect(taps, 1);
  });
}

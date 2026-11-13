import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_view/story_view.dart';

/// An animation that only counts who listens to it.
class _CountingAnimation extends AlwaysStoppedAnimation<double> {
  _CountingAnimation() : super(0);

  int listeners = 0;

  @override
  void addListener(VoidCallback listener) => listeners++;

  @override
  void removeListener(VoidCallback listener) => listeners--;
}

/// A 30 x 60 picture, decoded as the player does.
Future<ui.Codec> _codec() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 30, 60), Paint()..color = Colors.red);
  final image = await recorder.endRecording().toImage(30, 60);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return ui.instantiateImageCodec(png!.buffer.asUint8List());
}

void main() {
  testWidgets('the progress bar lets go of the animation when rebuilt', (
    tester,
  ) async {
    final animation = _CountingAnimation();
    Widget bar() => Directionality(
      textDirection: TextDirection.ltr,
      child: PageBar(
        [PageData(const Duration(seconds: 1), false)],
        animation,
        key: UniqueKey(),
      ),
    );

    // As StoryView builds it: a new key on every rebuild.
    for (var i = 0; i < 5; i++) {
      await tester.pumpWidget(bar());
    }
    expect(animation.listeners, 1, reason: 'only the bar on screen');

    await tester.pumpWidget(const SizedBox());
    expect(animation.listeners, 0);
  });

  testWidgets("an image story reports its size; its decoder can be let go", (
    tester,
  ) async {
    final loader = ImageLoader('https://media.test/story.jpg');
    await tester.runAsync(() async => loader.frames = await _codec());

    Size? reported;
    await tester.pumpWidget(
      MaterialApp(home: StoryImage(loader, onSize: (size) => reported = size)),
    );
    // The first frame comes from the engine.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(reported, const Size(30, 60));
    expect(find.byType(RawImage), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    loader.dispose();
    expect(loader.frames, isNull);

    // Nothing is loaded after that.
    var called = false;
    loader.loadImage(() => called = true);
    expect(called, isFalse);
  });
}

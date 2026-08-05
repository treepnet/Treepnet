import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// Isolates the one thing that has twice replaced the travel map with a red
/// error box: `flutter_map` asserts that the live camera still satisfies
/// `cameraConstraint` whenever the map's options are rebuilt. A panel resize
/// (the profile header collapsing) is what trips it.
///
/// These mirror the values in `travel_map.dart`, with no layers, so they run in
/// milliseconds instead of minutes.
void main() {
  final contentBounds = LatLngBounds(
    const LatLng(-58, -180),
    const LatLng(84, 180),
  );
  const homeCenter = LatLng(20, 10);
  const homeZoom = 1.2;

  Widget map(double width, double height) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: homeCenter,
            initialZoom: homeZoom,
            minZoom: homeZoom,
            maxZoom: 11,
            cameraConstraint: CameraConstraint.contain(bounds: contentBounds),
          ),
          children: const [],
        ),
      ),
    ),
  );

  testWidgets('builds at the phone panel size', (tester) async {
    await tester.pumpWidget(map(411, 317));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds at a tall panel (bigger phone / tablet)', (tester) async {
    await tester.pumpWidget(map(448, 500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives the panel growing, then shrinking', (tester) async {
    var height = 317.0;
    late StateSetter setOuter;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return SizedBox(
                width: 411,
                height: height,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: homeCenter,
                    initialZoom: homeZoom,
                    minZoom: homeZoom,
                    maxZoom: 11,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: contentBounds,
                    ),
                  ),
                  children: const [],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Exactly what the collapsing profile header does.
    setOuter(() => height = 460);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    setOuter(() => height = 700);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    setOuter(() => height = 317);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

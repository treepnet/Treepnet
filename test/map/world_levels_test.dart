import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/map/world_levels.dart';

void main() {
  group('WorldLevels', () {
    late Map<double, Completer<String>> pending;
    late List<double> asked;
    late WorldLevels<String> levels;
    late int notified;

    setUp(() {
      pending = {};
      asked = [];
      notified = 0;
      levels = WorldLevels<String>(
        steps: const [0.8, 0.32, 0.13],
        build: (step) {
          asked.add(step);
          return (pending[step] = Completer<String>()).future;
        },
      )..addListener(() => notified++);
    });

    test('nothing built yet: null, and the level is asked for once', () {
      expect(levels.at(0.32), isNull);
      expect(levels.at(0.32), isNull);
      expect(asked, [0.32]);
    });

    test(
      'a built level is answered at once and listeners hear of it',
      () async {
        levels.at(0.8);
        pending[0.8]!.complete('coarse');
        await Future<void>.delayed(Duration.zero);
        expect(notified, 1);
        expect(levels.at(0.8), 'coarse');
        expect(asked, [0.8]);
      },
    );

    test(
      'while a finer level builds, the closest coarser one stands in',
      () async {
        levels.prefetch([0.8]);
        pending[0.8]!.complete('coarse');
        await Future<void>.delayed(Duration.zero);
        expect(levels.at(0.13), 'coarse');
        expect(asked, [0.8, 0.13]);
        pending[0.13]!.complete('fine');
        await Future<void>.delayed(Duration.zero);
        expect(levels.at(0.13), 'fine');
      },
    );

    test('with no coarser one built, a finer one stands in', () async {
      levels.prefetch([0.13]);
      pending[0.13]!.complete('fine');
      await Future<void>.delayed(Duration.zero);
      expect(levels.at(0.8), 'fine');
    });

    test('a failed build is asked for again next time', () async {
      levels.at(0.32);
      pending[0.32]!.completeError(StateError('not loaded'));
      await Future<void>.delayed(Duration.zero);
      levels.at(0.32);
      expect(asked, [0.32, 0.32]);
    });
  });

  testWidgets('the background reader finds the same rings as the loaded map', (
    tester,
  ) async {
    await tester.runAsync(() => GeoRegions.instance.load());
    final geo = GeoRegions.instance;
    final rings = GeoRegions.readWorldRings(geo.geoBytes!);
    expect(rings.countries.length, geo.countryRings.length);
    final regionRings = [for (final r in geo.allRegions) ...r.rings];
    expect(rings.regions.length, regionRings.length);
    int points(List<List<Object>> list) =>
        list.fold(0, (sum, ring) => sum + ring.length);
    expect(points(rings.regions), points(regionRings));
  });
}

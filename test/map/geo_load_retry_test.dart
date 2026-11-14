import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/map/geo_regions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a failed load of the map is tried again on the next call', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // The asset can't be read (as on a phone out of memory).
    messenger.setMockMessageHandler('flutter/assets', (_) async => null);
    await expectLater(GeoRegions.instance.load(), throwsA(anything));
    expect(GeoRegions.instance.isLoaded, isFalse);

    // It used to hand back that same failure for the rest of the session.
    messenger.setMockMessageHandler('flutter/assets', null);
    await GeoRegions.instance.load();
    expect(GeoRegions.instance.isLoaded, isTrue);
  });
}

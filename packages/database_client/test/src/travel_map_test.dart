import 'dart:async';

import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:powersync_repository/powersync_repository.dart';

class _MockPowerSyncRepository extends Mock implements PowerSyncRepository {}

class _MockPostgrest extends Mock implements PostgrestClient {}

/// An RPC's answer, as PostgREST's builder (a Future) gives it.
class _Answer<T> extends Fake implements PostgrestFilterBuilder<T> {
  _Answer(this._value);

  final FutureOr<T> Function() _value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      Future<T>.sync(_value).then(onValue, onError: onError);
}

const _hamid = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Map<String, dynamic> _row(String id) => {
  'user_id': id,
  'regions': {'UZ-TK': 2, 'UZ-TO': 3},
  'points': [
    {
      'post_id': 'p1',
      'lat': 41.36,
      'lng': 69.23,
      'name': 'City',
      'thumb': 'https://photos/p1_480.jpg',
    },
    {'post_id': null, 'lat': 41.39, 'lng': 69.65, 'name': 'Rest'},
    {'post_id': 'bad', 'lat': null, 'lng': 1},
  ],
};

/// The new feed's globes (a prototype): each post's author's, from the
/// server's travel_maps.
void main() {
  test('a row reads as regions and pins, each post’s with its id', () {
    final map = TravelMap.fromRow(_row(_hamid));
    expect(map.regions, {'UZ-TK': 2, 'UZ-TO': 3});
    expect(map.pins, hasLength(2), reason: 'a pin with no spot is dropped');
    expect(map.pinOf('p1')?.lat, 41.36);
    expect(map.pinOf('p2'), isNull);
    expect(map.points.last.name, 'Rest');
    // Each post's small photo (migration 041); a story pin has none.
    expect(map.pinOf('p1')?.thumb, 'https://photos/p1_480.jpg');
    expect(map.pins.last.thumb, isNull);
  });

  test('a row from before 041, with no photos, still reads', () {
    final map = TravelMap.fromRow({
      'user_id': _hamid,
      'regions': <String, dynamic>{},
      'points': [
        {'post_id': 'p1', 'lat': 41.36, 'lng': 69.23, 'name': 'City'},
      ],
    });
    expect(map.pinOf('p1')?.thumb, isNull);
  });

  group('travelMapOf', () {
    late _MockPostgrest postgrest;
    late PowerSyncDatabaseClient client;
    var calls = 0;
    late FutureOr<List<dynamic>> Function() server;

    setUp(() {
      calls = 0;
      final repository = _MockPowerSyncRepository();
      postgrest = _MockPostgrest();
      when(repository.postgrest).thenReturn(postgrest);
      server = () => [_row(_hamid), _row(_other)];
      when(
        () => postgrest.rpc<List<dynamic>>(
          'travel_maps',
          params: any(named: 'params'),
        ),
      ).thenAnswer((_) {
        calls++;
        return _Answer<List<dynamic>>(() => server());
      });
      client = PowerSyncDatabaseClient(powerSyncRepository: repository);
    });

    test('several at once go as one call, and are kept', () async {
      final both = await Future.wait([
        client.travelMapOf(userId: _hamid),
        client.travelMapOf(userId: _other),
      ]);
      expect(both.every((m) => m != null), isTrue);
      expect(calls, 1);
      await client.travelMapOf(userId: _hamid);
      expect(calls, 1, reason: 'from the cache');
    });

    test('someone the server shows nothing of: null', () async {
      server = () => const [];
      expect(await client.travelMapOf(userId: _hamid), isNull);
    });

    test('offline: null, and nothing asked for a non-id', () async {
      server = () => throw Exception('offline');
      expect(await client.travelMapOf(userId: _hamid), isNull);
      expect(await client.travelMapOf(userId: 'not-an-id'), isNull);
    });

    test('signing out forgets them', () async {
      await client.travelMapOf(userId: _hamid);
      client.forgetServerSnapshots();
      await client.travelMapOf(userId: _hamid);
      expect(calls, 2);
    });
  });
}

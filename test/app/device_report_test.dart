import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/app/services/device_report.dart';

const _info = DeviceInfo(
  platform: 'android',
  appVersion: '1.0.9',
  build: 9,
  osVersion: '14',
  model: 'Samsung SM-S911B',
);

void main() {
  group('reportDue', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    const key = 'u1|1.0.9+9';
    String stamp(String k, DateTime at) => '$k|${at.toIso8601String()}';

    test('never sent', () {
      expect(reportDue(last: null, key: key, now: now), isTrue);
    });
    test('sent within the day', () {
      final last = stamp(key, now.subtract(const Duration(hours: 23)));
      expect(reportDue(last: last, key: key, now: now), isFalse);
    });
    test('sent a day ago', () {
      final last = stamp(key, now.subtract(const Duration(days: 1)));
      expect(reportDue(last: last, key: key, now: now), isTrue);
    });
    test('a new version or another account', () {
      final at = now.subtract(const Duration(minutes: 5));
      expect(reportDue(last: stamp('u1|1.0.8+8', at), key: key, now: now), isTrue);
      expect(reportDue(last: stamp('u2|1.0.9+9', at), key: key, now: now), isTrue);
    });
    test('a clock set back, or a stamp that does not read', () {
      final later = stamp(key, now.add(const Duration(hours: 2)));
      expect(reportDue(last: later, key: key, now: now), isTrue);
      expect(reportDue(last: 'junk', key: key, now: now), isTrue);
    });
  });

  test('an install id is a random version 4 UUID', () {
    final a = newDeviceId(Random(1));
    final b = newDeviceId(Random(2));
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(a, matches(v4));
    expect(b, matches(v4));
    expect(a, isNot(b));
  });

  test('an Android model has its maker once', () {
    expect(androidModel('samsung', 'SM-S911B'), 'Samsung SM-S911B');
    expect(androidModel('Xiaomi', 'Xiaomi 13T'), 'Xiaomi 13T');
    expect(androidModel('Google', 'Pixel 8'), 'Pixel 8');
    expect(androidModel('', 'X1'), 'X1');
  });

  test('an iPhone model is its name, else its identifier', () {
    expect(
      iosModel(modelName: 'iPhone 15 Pro', machine: 'iPhone16,1', physical: true),
      'iPhone 15 Pro',
    );
    expect(
      iosModel(modelName: 'Unknown device', machine: 'iPhone18,2', physical: true),
      'iPhone18,2',
    );
    expect(
      iosModel(modelName: 'iPhone 16', machine: 'arm64', physical: false),
      'Simulator',
    );
  });

  group('DeviceReporter', () {
    late DateTime now;
    late List<(String, DeviceInfo)> sent;
    late DeviceReporter reporter;

    Future<void> send(String id, DeviceInfo info) async => sent.add((id, info));

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = DateTime.utc(2026, 11, 17, 12);
      sent = [];
      reporter = DeviceReporter(read: () async => _info, now: () => now);
    });

    test('sends once a day, under the same install id', () async {
      await reporter.maybeReport(userId: 'u1', send: send);
      await reporter.maybeReport(userId: 'u1', send: send);
      expect(sent, hasLength(1));

      now = now.add(const Duration(days: 1));
      await reporter.maybeReport(userId: 'u1', send: send);
      expect(sent, hasLength(2));
      expect(sent[1].$1, sent[0].$1);
      expect(sent[0].$2.model, 'Samsung SM-S911B');
    });

    test('another account on the phone is sent at once', () async {
      await reporter.maybeReport(userId: 'u1', send: send);
      await reporter.maybeReport(userId: 'u2', send: send);
      expect(sent, hasLength(2));
      expect(sent[1].$1, sent[0].$1, reason: 'the same install');
    });

    test('a failed send is tried again on the next call', () async {
      await reporter.maybeReport(
        userId: 'u1',
        send: (_, __) async => throw Exception('offline'),
      );
      await reporter.maybeReport(userId: 'u1', send: send);
      expect(sent, hasLength(1));
    });

    test('signed out, then signed in: sent each time, one install', () async {
      await reporter.maybeReport(userId: '', send: send);
      await reporter.maybeReport(userId: '', send: send);
      expect(sent, hasLength(1));
      await reporter.maybeReport(userId: 'u1', send: send);
      expect(sent, hasLength(2));
      expect(sent[1].$1, sent[0].$1);
    });

    test('nothing is sent where the phone is not known', () async {
      final none = DeviceReporter(read: () async => null, now: () => now);
      await none.maybeReport(userId: 'u1', send: send);
      expect(sent, isEmpty);
    });
  });
}

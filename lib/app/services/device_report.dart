import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app tells the server about the phone it runs on.
@immutable
class DeviceInfo {
  const DeviceInfo({
    required this.platform,
    required this.appVersion,
    required this.build,
    this.osVersion,
    this.model,
  });

  /// `ios` or `android`.
  final String platform;

  /// e.g. 1.0.9 and 9.
  final String appVersion;
  final int build;

  /// e.g. 18.1 (iOS) or 14 (Android).
  final String? osVersion;

  /// e.g. iPhone 15 Pro, Samsung SM-S911B.
  final String? model;
}

/// Sends the phone's [DeviceInfo] under the install's [deviceId].
typedef DeviceSend = Future<void> Function(String deviceId, DeviceInfo info);

/// Tells the server, for the admin's Devices page, which phone, app version
/// and OS this install is, with the signed-in user or before anyone signs
/// in: once a day at most, and at once on a new version, a sign-in or a
/// sign-out. Each install has its own random id (not a hardware id), kept in
/// the app's preferences. Quiet when it can't get through: a later call tries
/// again.
class DeviceReporter {
  DeviceReporter({
    Future<DeviceInfo?> Function()? read,
    DateTime Function()? now,
  }) : _read = read ?? readDeviceInfo,
       _now = now ?? DateTime.now;

  final Future<DeviceInfo?> Function() _read;
  final DateTime Function() _now;

  /// The install's random id.
  static const idKey = 'treepnet_device_id';

  /// What was last sent and when: `user|version+build|time`.
  static const stampKey = 'treepnet_device_reported';

  /// How often the same phone, version and account is sent again.
  static const every = Duration(days: 1);

  Future<DeviceInfo?>? _info;
  bool _busy = false;

  /// Sends the phone through [send] if it is due: for [userId], or an empty
  /// one when no one is signed in.
  Future<void> maybeReport({
    required String userId,
    required DeviceSend send,
  }) async {
    if (_busy) return;
    _busy = true;
    try {
      final info = await (_info ??= _read());
      if (info == null) return;
      final prefs = await SharedPreferences.getInstance();
      final key = '$userId|${info.appVersion}+${info.build}';
      final now = _now();
      if (!reportDue(last: prefs.getString(stampKey), key: key, now: now)) {
        return;
      }
      var id = prefs.getString(idKey);
      if (id == null || !_uuid.hasMatch(id)) {
        id = newDeviceId();
        await prefs.setString(idKey, id);
      }
      await send(id, info);
      await prefs.setString(stampKey, '$key|${now.toUtc().toIso8601String()}');
    } catch (_) {
      // Offline or the server busy: nothing is stamped, a later call retries.
      // (A failed read is let go too, so it is read again.)
      _info = null;
    } finally {
      _busy = false;
    }
  }
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Whether the phone is to be sent again: never sent, sent for another
/// account or app version ([key]), or a day ago or more.
@visibleForTesting
bool reportDue({
  required String? last,
  required String key,
  required DateTime now,
}) {
  if (last == null) return true;
  final i = last.lastIndexOf('|');
  if (i < 0 || last.substring(0, i) != key) return true;
  final at = DateTime.tryParse(last.substring(i + 1));
  if (at == null) return true;
  // A clock set back counts as due as well.
  return now.isBefore(at) || now.difference(at) >= DeviceReporter.every;
}

/// A random (version 4) UUID: the install's id.
@visibleForTesting
String newDeviceId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// An Android model with its maker in front, once: `Samsung SM-S911B`,
/// `Pixel 8` (Google's models already say it).
@visibleForTesting
String androidModel(String manufacturer, String model) {
  final maker = manufacturer.trim();
  if (maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase())) {
    return model;
  }
  if (maker.toLowerCase() == 'google') return model;
  return '${maker[0].toUpperCase()}${maker.substring(1)} $model';
}

/// An iPhone's model: its name where the plugin knows it (`iPhone 15 Pro`),
/// else its identifier (`iPhone18,2`: a model newer than the plugin's list,
/// which it calls "Unknown device"). A simulator says so.
@visibleForTesting
String iosModel({
  required String modelName,
  required String machine,
  required bool physical,
}) {
  if (!physical) return 'Simulator';
  if (modelName.isNotEmpty && modelName != 'Unknown device') return modelName;
  return machine;
}

/// The phone this runs on; null where it isn't a phone (web, desktop).
Future<DeviceInfo?> readDeviceInfo() async {
  if (kIsWeb) return null;
  final package = await PackageInfo.fromPlatform();
  final build = int.tryParse(package.buildNumber) ?? 0;
  final plugin = DeviceInfoPlugin();
  if (Platform.isIOS) {
    final ios = await plugin.iosInfo;
    return DeviceInfo(
      platform: 'ios',
      appVersion: package.version,
      build: build,
      osVersion: ios.systemVersion,
      model: iosModel(
        modelName: ios.modelName,
        machine: ios.utsname.machine,
        physical: ios.isPhysicalDevice,
      ),
    );
  }
  if (Platform.isAndroid) {
    final android = await plugin.androidInfo;
    return DeviceInfo(
      platform: 'android',
      appVersion: package.version,
      build: build,
      osVersion: android.version.release,
      model: androidModel(android.manufacturer, android.model),
    );
  }
  return null;
}

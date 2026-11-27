import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// The app reaches PowerSync through powersync_repository; the type is needed
// here to open one.
// ignore: depend_on_referenced_packages
import 'package:powersync/powersync.dart';
import 'package:shared/shared.dart' as shared;

/// A real PowerSync database for a test: the app's schema in a temporary
/// file, never connected (offline, nothing synced yet), closed and deleted
/// when the test ends. powersync 2.0 made PowerSyncDatabase a base class, so
/// it can no longer be mocked.
///
/// In a widget test, open it in setUp or inside `tester.runAsync`: its work
/// happens on another isolate, which fake time doesn't drive.
Future<PowerSyncDatabase> openTestPowerSyncDb() async {
  final dir = Directory.systemTemp.createTempSync('treepnet_powersync_test');
  final db = PowerSyncDatabase(
    schema: shared.schema,
    path: '${dir.path}/test.db',
  );
  await db.initialize();
  addTearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });
  return db;
}

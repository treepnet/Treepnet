import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:app_ui/app_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:token_storage/token_storage.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';
import 'package:treepnet/map/geo_regions.dart';
import 'package:treepnet/monitoring/crash_reporter.dart';
import 'package:treepnet/notifications/push/push_notifications.dart';

typedef AppBuilder =
    FutureOr<Widget> Function(
      PowerSyncRepository,
      SharedPreferences,
      MediaUploadQueue,
    );

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError ${bloc.runtimeType}', error: error, stackTrace: stackTrace);
    // Augment, don't replace: keep the existing console log, and also report
    // the bloc error to Treepnet's crash logger (fire-and-forget, no throw).
    CrashReporter.instance.report(error, stackTrace, kind: 'bloc');
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(
  AppBuilder builder, {
  required AppFlavor appFlavor,
}) async {
  FlutterError.onError = (details) {
    logE(details.exceptionAsString(), stackTrace: details.stack);
    CrashReporter.instance.report(
      details.exception,
      details.stack,
      kind: 'flutter',
    );
  };

  Bloc.observer = const AppBlocObserver();

  await runZonedGuarded(
    () async {
      // TEMPORARY startup diagnostics. Each stage prints before it runs; the
      // LAST "TREEP_BOOT" line seen in the device log (Xcode / Console.app) is
      // the stage that hung. Remove once the real-device splash hang is fixed.
      void boot(String stage) => debugPrint('TREEP_BOOT: $stage');

      boot('0 ensureInitialized');
      WidgetsFlutterBinding.ensureInitialized();

      // Crash logger: gather app/device context and flush any offline-queued
      // reports. Off the critical path (unawaited) so it can never delay the
      // first frame; the error hooks above already work without it.
      unawaited(CrashReporter.instance.init(env: appFlavor.flavor.name));

      boot('1 hydrated storage (start)');
      HydratedBloc.storage = await _settingsStorage();
      boot('2 hydrated storage (ok)');

      final powerSyncRepository = PowerSyncRepository(env: appFlavor.getEnv);
      boot('3 powersync.initialize (start)');
      await powerSyncRepository.initialize();
      boot('4 powersync.initialize (ok)');

      // Firebase must be up BEFORE the auth client (built in `builder`) touches
      // FirebaseAuth, and before push. Awaited + bounded so a hang can't freeze
      // the splash; it no-ops if a flavor has no Firebase config.
      boot('4b firebase.initializeApp (start)');
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp().timeout(const Duration(seconds: 10));
        }
        boot('4b firebase.initializeApp (ok)');
      } catch (error) {
        boot('4b firebase.initializeApp SKIPPED: $error');
      }

      // Firebase Cloud Messaging (push). Push is NOT needed to render the first
      // screen, so keep it OFF the startup critical path: a slow or hanging
      // Firebase init on a real device can then never freeze the splash. It
      // no-ops on a flavor with no Firebase config and swallows its own errors.
      boot('5 push.initialize (non-blocking, off critical path)');
      unawaited(
        PushNotifications.initialize().then(
          (_) => boot('6 push.initialize (ok, background)'),
        ),
      );

      boot('7 sharedPreferences (start)');
      final sharedPreferences = await SharedPreferences.getInstance();
      boot('8 sharedPreferences (ok)');

      // Uploads ask the backend for a per-file link as the signed-in user.
      MediaStorage.instance.idToken = EntraSession.instance.idToken;

      final mediaUploadQueue = MediaUploadQueue(
        db: powerSyncRepository.db(),
        sharedPreferences: sharedPreferences,
      )..start();

      SystemUiOverlayTheme.setPortraitOrientation();

      boot('9 builder + runApp (start)');
      runApp(
        await builder(
          powerSyncRepository,
          sharedPreferences,
          mediaUploadQueue,
        ),
      );
      boot('10 runApp (done)');

      // The world map data (profile globe, onboarding, place picker) loads in
      // a background isolate; start it once the first screen is up, so it's
      // ready before any of those opens.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(
          const Duration(seconds: 2),
          () => unawaited(GeoRegions.instance.load()),
        );
      });
    },
    (error, stack) {
      debugPrint('TREEP_BOOT: ERROR $error');
      logE(error.toString(), stackTrace: stack);
      CrashReporter.instance.report(error, stack, kind: 'zone');
    },
  );
}

/// Where the app keeps its saved settings — the language and the theme, the
/// only blocs that still persist their state.
///
/// They used to live in the temporary folder, which the OS (or "Clear cache")
/// may wipe, next to the state of every post, comment and story ever shown,
/// which piled up forever and was all read on each start. Now they live in
/// the app-support folder: the two settings are carried over once and the old
/// store is deleted.
Future<Storage> _settingsStorage() async {
  if (kIsWeb) {
    return HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory.web,
    );
  }
  const keep = ['LocaleBloc', 'ThemeModeBloc'];
  final carried = <String, dynamic>{};
  final oldDir = (await getTemporaryDirectory()).path;
  if (File('$oldDir/hydrated_box.hive').existsSync()) {
    try {
      final old = await HydratedStorage.build(
        storageDirectory: HydratedStorageDirectory(oldDir),
      );
      for (final key in keep) {
        final value = old.read(key);
        if (value != null) carried[key] = value;
      }
      await old.close();
    } catch (_) {
      // Unreadable: the settings fall back to their defaults.
    }
    for (final name in ['hydrated_box.hive', 'hydrated_box.lock']) {
      try {
        File('$oldDir/$name').deleteSync();
      } catch (_) {}
    }
  }
  final storage = await HydratedStorage.build(
    storageDirectory: HydratedStorageDirectory(
      (await getApplicationSupportDirectory()).path,
    ),
  );
  for (final MapEntry(:key, :value) in carried.entries) {
    if (storage.read(key) == null) await storage.write(key, value);
  }
  return storage;
}

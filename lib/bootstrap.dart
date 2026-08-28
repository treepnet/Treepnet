import 'dart:async';
import 'dart:developer';

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
import 'package:treepnet/app/services/media_upload_queue.dart';
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
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap(
  AppBuilder builder, {
  required AppFlavor appFlavor,
}) async {
  FlutterError.onError = (details) {
    logE(details.exceptionAsString(), stackTrace: details.stack);
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

      boot('1 hydrated storage (start)');
      HydratedBloc.storage = await HydratedStorage.build(
        storageDirectory: kIsWeb
            ? HydratedStorageDirectory.web
            : HydratedStorageDirectory((await getTemporaryDirectory()).path),
      );
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
    },
    (error, stack) {
      debugPrint('TREEP_BOOT: ERROR $error');
      logE(error.toString(), stackTrace: stack);
    },
  );
}

import 'dart:async';
import 'dart:developer';

import 'package:app_ui/app_ui.dart';
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
      WidgetsFlutterBinding.ensureInitialized();


      HydratedBloc.storage = await HydratedStorage.build(
        storageDirectory: kIsWeb
            ? HydratedStorageDirectory.web
            : HydratedStorageDirectory((await getTemporaryDirectory()).path),
      );

      final powerSyncRepository = PowerSyncRepository(env: appFlavor.getEnv);
      await powerSyncRepository.initialize();


      // Firebase Cloud Messaging (push). No-ops on a flavor with no Firebase
      // config; never blocks startup on failure.
      await PushNotifications.initialize();

      final sharedPreferences = await SharedPreferences.getInstance();

      final mediaUploadQueue = MediaUploadQueue(
        db: powerSyncRepository.db(),
        sharedPreferences: sharedPreferences,
      )..start();

      SystemUiOverlayTheme.setPortraitOrientation();

      runApp(
        await builder(
          powerSyncRepository,
          sharedPreferences,
          mediaUploadQueue,
        ),
      );
    },
    (error, stack) {
      logE(error.toString(), stackTrace: stack);
    },
  );
}

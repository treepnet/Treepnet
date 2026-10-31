import 'package:database_client/database_client.dart';
import 'package:flutter/foundation.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/bootstrap.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  bootstrap(appFlavor: AppFlavor.production(), (
    powerSyncRepository,
    sharedPreferences,
    mediaUploadQueue,
  ) async {


    final authenticationClient = FirebaseAuthenticationClient(
      powerSyncRepository: powerSyncRepository,
    );
    // Restore any persisted Firebase session before the app reads the first user.
    // It returns within ~2 s even offline: a signed-in user opens straight into
    // the app with what's on the phone, and the token follows in the
    // background. The timeout is only a safety net.
    debugPrint('TREEP_BOOT: 9a restoreSession (start)');
    await authenticationClient.restoreSession().timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          debugPrint('TREEP_BOOT: restoreSession TIMEOUT — continuing'),
    );
    debugPrint('TREEP_BOOT: 9b restoreSession (ok)');

    final databaseClient = PowerSyncDatabaseClient(
      powerSyncRepository: powerSyncRepository,
    );

    final persistentStorage = PersistentStorage(
      sharedPreferences: sharedPreferences,
    );

    final storiesStorage = StoriesStorage(storage: persistentStorage);

    final userRepository = UserRepository(
      databaseClient: databaseClient,
      authenticationClient: authenticationClient,
    );

    final searchRepository = SearchRepository(databaseClient: databaseClient);

    final postsRepository = PostsRepository(databaseClient: databaseClient);

    final storiesRepository = StoriesRepository(
      databaseClient: databaseClient,
      storage: storiesStorage,
    );

    // Bounded fallback: the user stream emits immediately today, but never let
    // a future regression here freeze the splash — default to signed-out.
    debugPrint('TREEP_BOOT: 9c user.first (start)');
    final currentUser = await userRepository.user.first.timeout(
      const Duration(seconds: 8),
      onTimeout: () => User.anonymous,
    );
    debugPrint('TREEP_BOOT: 9d user.first (ok)');

    return App(
      userRepository: userRepository,
      postsRepository: postsRepository,
      storiesRepository: storiesRepository,
      searchRepository: searchRepository,
      mediaUploadQueue: mediaUploadQueue,
      powerSyncRepository: powerSyncRepository,
      user: currentUser,
    );
  });
}

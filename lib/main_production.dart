import 'package:chats_repository/chats_repository.dart';
import 'package:database_client/database_client.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/bootstrap.dart';
import 'package:persistent_storage/persistent_storage.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:entra_authentication_client/entra_authentication_client.dart';
import 'package:user_repository/user_repository.dart';

void main() {
  bootstrap(appFlavor: AppFlavor.production(), (
    powerSyncRepository,
    sharedPreferences,
    mediaUploadQueue,
  ) async {


    final authenticationClient = EntraAuthenticationClient(
      powerSyncRepository: powerSyncRepository,
    );
    // Restore any persisted Entra session before the app reads the first user.
    await authenticationClient.restoreSession();

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

    final chatsRepository = ChatsRepository(databaseClient: databaseClient);

    final storiesRepository = StoriesRepository(
      databaseClient: databaseClient,
      storage: storiesStorage,
    );

    return App(
      userRepository: userRepository,
      postsRepository: postsRepository,
      chatsRepository: chatsRepository,
      storiesRepository: storiesRepository,
      searchRepository: searchRepository,
      mediaUploadQueue: mediaUploadQueue,
      powerSyncRepository: powerSyncRepository,
      user: await userRepository.user.first,
    );
  });
}

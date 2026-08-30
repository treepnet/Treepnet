import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/feed.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/selector/selector.dart';
import 'package:posts_repository/posts_repository.dart';
// `show`: the package also exports sqlite3's `Row`, which collides with the
// widget of the same name.
import 'package:powersync_repository/powersync_repository.dart'
    show PowerSyncRepository;
import 'package:search_repository/search_repository.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart';
import 'package:treepnet/app/services/media_upload_queue.dart';

/// Key to access the [AppSnackbarState] from the [BuildContext].
final snackbarKey = GlobalKey<AppSnackbarState>();

/// Localizations for code that has no [BuildContext] (blocs, top-level helpers
/// like [openSnackbar] callers). Resolves through the global snackbar key's
/// context; falls back to English before the widget tree is mounted.
AppLocalizations get l10nGlobal {
  final context = snackbarKey.currentContext;
  return context != null
      ? AppLocalizations.of(context)
      : lookupAppLocalizations(const Locale('en'));
}

/// Key to access the [AppLoadingIndeterminateState] from the
/// [BuildContext].
final loadingIndeterminateKey = GlobalKey<AppLoadingIndeterminateState>();

class App extends StatelessWidget {
  const App({
    required this.user,
    required this.userRepository,
    required this.postsRepository,
    required this.storiesRepository,
    required this.searchRepository,
    required this.mediaUploadQueue,
    required this.powerSyncRepository,
    super.key,
  });

  final User user;
  final UserRepository userRepository;
  final PostsRepository postsRepository;
  final StoriesRepository storiesRepository;
  final SearchRepository searchRepository;
  final MediaUploadQueue mediaUploadQueue;

  /// Exposed so screens can tell whether the first sync has landed. The feed
  /// reads the local database on its first frame, well before PowerSync has
  /// anything in it, and needs to know when to look again.
  final PowerSyncRepository powerSyncRepository;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: userRepository),
        RepositoryProvider.value(value: postsRepository),
        RepositoryProvider.value(value: storiesRepository),
        RepositoryProvider.value(value: searchRepository),
        RepositoryProvider.value(value: mediaUploadQueue),
        RepositoryProvider.value(value: powerSyncRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AppBloc(user: user, userRepository: userRepository),
          ),
          BlocProvider(create: (_) => LocaleBloc()),
          BlocProvider(create: (_) => ThemeModeBloc()),
          BlocProvider(
            create: (context) =>
                FeedBloc(postsRepository: context.read<PostsRepository>()),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

/// Snack bar to show messages to the user.
void openSnackbar(
  SnackbarMessage message, {
  bool clearIfQueue = false,
  bool undismissable = false,
}) {
  snackbarKey.currentState?.post(
    message,
    clearIfQueue: clearIfQueue,
    undismissable: undismissable,
  );
}

void toggleLoadingIndeterminate({bool enable = true, bool autoHide = false}) =>
    loadingIndeterminateKey.currentState?.setVisibility(
      visible: enable,
      autoHide: autoHide,
    );

/// Closes all snack bars.
void closeSnackbars() => snackbarKey.currentState?.closeAll();

void showCurrentlyUnavailableFeature({bool clearIfQueue = true}) =>
    openSnackbar(
      SnackbarMessage.error(
        title: l10nGlobal.featureNotAvailableText,
        description: l10nGlobal.featureNotAvailableDescriptionText,
        icon: Icons.error_outline,
      ),
      clearIfQueue: clearIfQueue,
    );

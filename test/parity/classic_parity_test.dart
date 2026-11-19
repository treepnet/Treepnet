// The usual feed's post, as on chat-integration (prod): goldens taken there
// and checked on the feature branch, to prove the features changed no pixel
// of the posts everywhere else. Regenerate only on chat-integration:
// flutter test --update-goldens test/parity/classic_parity_test.dart.
import 'package:app_ui/app_ui.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/post/post.dart' show PostView;
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

void main() {
  late _MockAppBloc app;
  late _MockPostsRepository posts;
  late _MockUserRepository users;
  late _MockStoriesRepository stories;

  setUpAll(initializeDateFormatting);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app = _MockAppBloc();
    posts = _MockPostsRepository();
    users = _MockUserRepository();
    stories = _MockStoriesRepository();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    when(
      () => posts.statsOf(postId: any(named: 'postId')),
    ).thenAnswer((_) => const Stream<PostStats>.empty());
    when(
      () => users.travelTierOf(userId: any(named: 'userId')),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(
      () => stories.mergedStories(
        authorId: any(named: 'authorId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => const Stream<List<Story>>.empty());
  });

  final shot = GlobalKey();

  PostLargeBlock post({required String caption, int photos = 1}) =>
      PostLargeBlock(
        id: 'post-1',
        author: const PostAuthor(
          id: 'author',
          avatarUrl: '',
          username: 'traveller',
        ),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        media: [
          for (var i = 0; i < photos; i++)
            ImageMedia(id: 'm$i', url: 'file:///parity-missing/$i.jpg'),
        ],
        caption: caption,
        location: 'Tashkent',
      );

  for (final dark in [true, false]) {
    for (final (name, caption, photos) in [
      ('one_photo', 'A day in Samarkand, the blue domes in the morning sun.', 1),
      ('three_photos', '', 3),
    ]) {
      testWidgets('the usual post: $name (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          BlocProvider<AppBloc>.value(
            value: app,
            child: MultiRepositoryProvider(
              providers: [
                RepositoryProvider<PostsRepository>.value(value: posts),
                RepositoryProvider<UserRepository>.value(value: users),
                RepositoryProvider<StoriesRepository>.value(value: stories),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark
                    ? const AppDarkTheme().theme
                    : const AppTheme().theme,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                locale: const Locale('en'),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: shot,
                      child: Builder(
                        builder: (context) => ColoredBox(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: SizedBox(
                            width: 440,
                            child: CustomScrollView(
                              shrinkWrap: true,
                              slivers: [
                                SliverList.list(
                                  children: [
                                    PostView(
                                      block: post(
                                        caption: caption,
                                        photos: photos,
                                      ),
                                      postIndex: 1,
                                      withInViewNotifier: false,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        await expectLater(
          find.byKey(shot),
          matchesGoldenFile(
            'goldens/classic_${name}_${dark ? 'dark' : 'light'}.png',
          ),
        );
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/new_feed/feed_globe_mode.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class MockPostsRepository extends Mock implements PostsRepository {}

class MockUserRepository extends Mock implements UserRepository {}

/// The post on the globe: 'post-1' by 'author', its pin in Tashkent
/// ([tashkentMap]).
final globePost = PostLargeBlock(
  id: 'post-1',
  author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
  createdAt: DateTime(2026),
  media: const [ImageMedia(id: 'm1', url: '')],
  caption: '',
);

/// The author's travel map: one region, the post's pin.
const tashkentMap = TravelMap(
  regions: {'UZ-TK': 1},
  pins: [(postId: 'post-1', lat: 41.36, lng: 69.23, name: 'City', thumb: null)],
);

/// What a post's globe (FeedPostGlobe) needs around it: the signed-in
/// account ('me'), the posts and users repositories (mocked: the author's
/// map is [tashkentMap]), and a list in [FeedGlobeMode].
class GlobeHarness {
  GlobeHarness() {
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    when(
      () => posts.statsOf(postId: any(named: 'postId')),
    ).thenAnswer((_) => const Stream<PostStats>.empty());
    when(
      () => posts.travelMapOf(userId: 'author'),
    ).thenAnswer((_) async => tashkentMap);
  }

  final app = MockAppBloc();
  final posts = MockPostsRepository();
  final users = MockUserRepository();

  /// [child] in a page of the app, in a [style] list ([onScreen]: whether
  /// the list is shown; [viewportHeight]: how tall it shows).
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    FeedGlobeStyle style = FeedGlobeStyle.card,
    ValueListenable<bool>? onScreen,
    double? viewportHeight,
  }) => tester.pumpWidget(
    MultiBlocProvider(
      providers: [BlocProvider<AppBloc>.value(value: app)],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<PostsRepository>.value(value: posts),
          RepositoryProvider<UserRepository>.value(value: users),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: FeedGlobeMode(
              style: style,
              onScreen: onScreen,
              viewportHeight: viewportHeight,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// [children] in a list as the globe lists are: it scrolls by its arrows
/// (and the top bar) only — a finger drag never scrolls it.
Widget globeList(ScrollController scroll, List<Widget> children) => ListView(
  controller: scroll,
  physics: const NeverScrollableScrollPhysics(),
  children: children,
);

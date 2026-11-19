import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:instagram_blocks_ui/instagram_blocks_ui.dart' show TimeAgo;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/feed/new_feed/feed_post_globe.dart';
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/feed/post/post.dart' show PostView;
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockPostsRepository extends Mock implements PostsRepository {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

/// The new feed (a prototype): under each post's globe, its description up
/// level with the arrows, its time under that; its country and city on the
/// globe itself.
void main() {
  setUpAll(initializeDateFormatting);

  late _MockAppBloc app;
  late _MockPostsRepository posts;
  late _MockUserRepository users;
  late _MockStoriesRepository stories;

  setUp(() {
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
      () => posts.travelMapOf(userId: any(named: 'userId')),
    ).thenAnswer((_) async => null);
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

  PostLargeBlock postWith(String caption) => PostLargeBlock(
    id: 'post-1',
    author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
    createdAt: DateTime(2026),
    media: const [ImageMedia(id: 'm', url: '')],
    caption: caption,
    location: 'Samarkand',
  );

  final post = PostLargeBlock(
    id: 'post-1',
    author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
    createdAt: DateTime(2026),
    media: const [ImageMedia(id: 'm', url: '')],
    caption: 'Samarkand at dawn',
    location: 'Samarkand',
  );

  Future<void> pump(WidgetTester tester, {PostLargeBlock? block}) async {
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              // The new feed: FeedGlobeMode's defaults.
              body: FeedGlobeMode(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        width: 300,
                        child: PostView(block: block ?? post, postIndex: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('the description level with the arrows, its time under it', (
    tester,
  ) async {
    await pump(tester);
    final caption = find.text('Samarkand at dawn');
    expect(caption, findsOneWidget);
    final down = tester.getCenter(find.byKey(const ValueKey('feedPostDown')));
    final up = tester.getCenter(find.byKey(const ValueKey('feedPostUp')));
    expect(tester.getCenter(caption).dy, closeTo(down.dy, 0.5));
    expect(tester.getRect(caption).right, lessThan(up.dx));
    expect(find.byType(TimeAgo), findsOneWidget);
    final time = tester.getRect(find.byType(TimeAgo));
    expect(time.top, greaterThan(tester.getRect(caption).bottom));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a long description: its first line short of the arrows, the '
      'rest under it the whole width', (tester) async {
    const long =
        'We walked from the Registan to Shah-i-Zinda at dawn, before the '
        'tour buses came, and the blue tiles of every dome caught the first '
        'light one after another while the city was still asleep.';
    await pump(tester, block: postWith(long));
    final first = tester.getRect(
      find.byKey(const ValueKey('feedPostCaptionFirst')),
    );
    final rest = tester.getRect(
      find.byKey(const ValueKey('feedPostCaptionRest')),
    );
    final up = tester.getRect(find.byKey(const ValueKey('feedPostUp')));
    final down = tester.getCenter(find.byKey(const ValueKey('feedPostDown')));
    // The first line beside the arrows, stopping short of them.
    expect(first.right, lessThanOrEqualTo(up.left));
    expect(first.center.dy, closeTo(down.dy, 1));
    // The rest straight under it, as wide as the line goes (under the
    // arrows too).
    expect(rest.left, closeTo(first.left, 0.5));
    expect(rest.top, closeTo(first.bottom, 0.5));
    expect(rest.right, greaterThan(up.left));
    // None of it lost.
    final firstText = tester
        .widget<Text>(find.byKey(const ValueKey('feedPostCaptionFirst')))
        .data!;
    final restText = tester
        .widget<Text>(find.byKey(const ValueKey('feedPostCaptionRest')))
        .data!;
    expect('$firstText $restText', long);
    // And all of the first line drawn: none of it cut at the arrows.
    final drawn = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byKey(const ValueKey('feedPostCaptionFirst')),
        matching: find.byType(RichText),
      ),
    );
    expect(
      drawn.getMaxIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(drawn.size.width + 0.01),
    );
    // Its time under it all.
    expect(tester.getRect(find.byType(TimeAgo)).top, greaterThan(rest.bottom));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('no description: its time up level with the arrows instead', (
    tester,
  ) async {
    await pump(tester, block: postWith(''));
    final time = find.byType(TimeAgo);
    expect(time, findsOneWidget, reason: 'there, and not under it too');
    final down = tester.getCenter(find.byKey(const ValueKey('feedPostDown')));
    final up = tester.getCenter(find.byKey(const ValueKey('feedPostUp')));
    expect(tester.getCenter(time).dy, closeTo(down.dy, 0.5));
    expect(tester.getRect(time).right, lessThan(up.dx));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('its country and city on the globe, not under it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(FeedPostPlace), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FeedPostGlobe),
        matching: find.byType(FeedPostPlace),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:search_repository/search_repository.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/search/view/search_page.dart';
import 'package:user_repository/user_repository.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockUserRepository extends Mock implements UserRepository {}

class _MockSearchRepository extends Mock implements SearchRepository {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

/// The search page, before anything is typed: suggested people (as the
/// chat's Type tab suggests them), 30 of them; a search shows its results
/// instead, and clearing it brings the suggestions back.
void main() {
  late _MockAppBloc app;
  late _MockUserRepository users;
  late _MockSearchRepository search;
  late _MockStoriesRepository stories;

  final suggested = [
    for (var i = 0; i < 30; i++)
      User(id: 'suggested-$i', username: 'traveller$i', fullName: 'T $i'),
  ];

  setUp(() {
    app = _MockAppBloc();
    users = _MockUserRepository();
    search = _MockSearchRepository();
    stories = _MockStoriesRepository();
    whenListen(
      app,
      const Stream<AppState>.empty(),
      initialState: const AppState.authenticated(User(id: 'me')),
    );
    when(
      () => users.suggestedUsers(limit: any(named: 'limit')),
    ).thenAnswer((_) async => [const User(id: 'me'), ...suggested]);
    when(
      () => users.travelTierOf(userId: any(named: 'userId')),
    ).thenAnswer((_) => const Stream<int>.empty());
    when(
      () => search.searchUsers(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => const [
        User(id: 'found', username: 'samarkand', fullName: 'S'),
      ],
    );
    when(
      () => stories.mergedStories(
        authorId: any(named: 'authorId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => const Stream<List<Story>>.empty());
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider<AppBloc>.value(
        value: app,
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<UserRepository>.value(value: users),
            RepositoryProvider<SearchRepository>.value(value: search),
            RepositoryProvider<StoriesRepository>.value(value: stories),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: SearchView(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('nothing typed: 30 suggested people, never oneself', (
    tester,
  ) async {
    await pump(tester);
    verify(() => users.suggestedUsers(limit: 30)).called(1);
    expect(find.text('traveller0'), findsOneWidget);
    expect(find.text('traveller1'), findsOneWidget);
    expect(find.byKey(const ValueKey('me')), findsNothing);
    // All 30, down the list.
    await tester.scrollUntilVisible(
      find.text('traveller29'),
      300,
      // The list's, not the text field's own.
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('traveller29'), findsOneWidget);
    verifyNever(
      () => search.searchUsers(
        query: any(named: 'query'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    );
  });

  testWidgets('typed: the results in their place; cleared: back again', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'sam');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('samarkand'), findsOneWidget);
    expect(find.text('traveller0'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text('traveller0'), findsOneWidget);
    expect(find.text('samarkand'), findsNothing);
    // Asked for once: back at once, no new request.
    verify(() => users.suggestedUsers(limit: 30)).called(1);
  });
}

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/stories/stories.dart';
import 'package:user_repository/user_repository.dart' show User;

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc {}

class _MockStoriesRepository extends Mock implements StoriesRepository {}

/// A list that reorders (the chats, on every message) reuses an avatar for
/// another person: the ring must follow the person, not the place.
void main() {
  testWidgets('an avatar reused for another author shows that author', (
    tester,
  ) async {
    final app = _MockAppBloc();
    when(
      () => app.state,
    ).thenReturn(const AppState.authenticated(User(id: 'me')));
    final stories = _MockStoriesRepository();
    when(
      () => stories.mergedStories(
        authorId: any(named: 'authorId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => const Stream<List<Story>>.empty());

    Widget avatarOf(String id) => BlocProvider<AppBloc>.value(
      value: app,
      child: RepositoryProvider<StoriesRepository>.value(
        value: stories,
        child: MaterialApp(
          home: Scaffold(
            body: UserStoriesAvatar(author: User(id: id)),
          ),
        ),
      ),
    );

    String shownAuthor() => tester
        .element(find.byType(ProfileAvatar))
        .read<UserStoriesBloc>()
        .state
        .author
        .id;

    await tester.pumpWidget(avatarOf('a'));
    await tester.pump();
    expect(shownAuthor(), 'a');

    await tester.pumpWidget(avatarOf('b'));
    await tester.pump();
    expect(shownAuthor(), 'b');
  });
}

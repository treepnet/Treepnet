import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPostsRepository extends Mock implements PostsRepository {}

void main() {
  const me = 'me';

  late _MockUserRepository users;

  /// The people the profile follows, as the server has them, newest first.
  final everyone = [for (var i = 0; i < 45; i++) User(id: 'u$i')];

  /// Each ask, as `offset+limit`.
  late List<String> asked;
  var refuse = false;

  setUp(() {
    users = _MockUserRepository();
    asked = [];
    refuse = false;
    when(() => users.currentUserId).thenReturn(me);
    when(() => users.profileScope(any())).thenReturn(SyncScope.none());
    when(
      () => users.getFollowings(
        userId: me,
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((call) async {
      final limit = call.namedArguments[#limit] as int;
      final offset = call.namedArguments[#offset] as int;
      asked.add('$offset+$limit');
      if (refuse) throw Exception('offline');
      return everyone.skip(offset).take(limit).toList();
    });
  });

  UserProfileBloc open() => UserProfileBloc(
    userRepository: users,
    postsRepository: _MockPostsRepository(),
    userId: me,
  );

  test('pages come one at a time, added under the ones shown', () async {
    final bloc = open()..add(const UserProfileFollowingsListRequested());
    await pumpEventQueue();
    expect(bloc.state.followings, hasLength(20));
    expect(bloc.state.followingsStatus, FollowListStatus.done);

    bloc.add(const UserProfileFollowListMoreRequested(followers: false));
    await pumpEventQueue();
    bloc.add(const UserProfileFollowListMoreRequested(followers: false));
    await pumpEventQueue();

    expect(asked, ['0+20', '20+20', '40+20'], reason: 'never the whole again');
    expect(bloc.state.followings.map((u) => u.id), [
      for (final u in everyone) u.id,
    ]);
    expect(bloc.state.followingsEnd, isTrue, reason: '5 came back for 20');

    // At the end, scrolling asks nothing more.
    bloc.add(const UserProfileFollowListMoreRequested(followers: false));
    await pumpEventQueue();
    expect(asked, hasLength(3));
    await bloc.close();
  });

  test('a refused page says so, keeps the list, and Retry goes on', () async {
    final bloc = open()..add(const UserProfileFollowingsListRequested());
    await pumpEventQueue();
    refuse = true;
    bloc.add(const UserProfileFollowListMoreRequested(followers: false));
    await pumpEventQueue();
    expect(bloc.state.followingsStatus, FollowListStatus.failed);
    expect(bloc.state.followings, hasLength(20));

    refuse = false;
    bloc.add(const UserProfileFollowListMoreRequested(followers: false));
    await pumpEventQueue();
    expect(bloc.state.followings, hasLength(40));
    await bloc.close();
  });

  test('a first page refused: failed, with nothing shown', () async {
    refuse = true;
    final bloc = open()..add(const UserProfileFollowingsListRequested());
    await pumpEventQueue();
    expect(bloc.state.followingsStatus, FollowListStatus.failed);
    expect(bloc.state.followings, isEmpty);
    await bloc.close();
  });
}

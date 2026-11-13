import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPostsRepository extends Mock implements PostsRepository {}

/// The follow button says what it will do; the bloc does that, once.
void main() {
  const me = 'me';
  late _MockUserRepository users;
  late UserProfileBloc bloc;

  setUp(() {
    users = _MockUserRepository();
    when(() => users.currentUserId).thenReturn(me);
    when(() => users.profileScope(any())).thenReturn(SyncScope.none());
    when(
      () => users.follow(followToId: any(named: 'followToId')),
    ).thenAnswer((_) async {});
    when(
      () => users.unfollow(unfollowId: any(named: 'unfollowId')),
    ).thenAnswer((_) async {});
    // The user's own profile page (a list of their followers / followings).
    bloc = UserProfileBloc(
      userRepository: users,
      postsRepository: _MockPostsRepository(),
    );
  });

  tearDown(() => bloc.close());

  test('Follow follows, and a quick second tap does nothing more', () async {
    bloc
      ..add(const UserProfileFollowUserRequested(userId: 'a'))
      // The pill already shows "Requested" / "Following": the rest of a
      // double tap used to undo the follow.
      ..add(const UserProfileFollowUserRequested(userId: 'a', follow: false));
    await pumpEventQueue();
    verify(() => users.follow(followToId: 'a')).called(1);
    verifyNever(() => users.unfollow(unfollowId: any(named: 'unfollowId')));
  });

  test('two people followed in a row: both', () async {
    bloc
      ..add(const UserProfileFollowUserRequested(userId: 'a'))
      ..add(const UserProfileFollowUserRequested(userId: 'b'));
    await pumpEventQueue();
    verify(() => users.follow(followToId: 'a')).called(1);
    verify(() => users.follow(followToId: 'b')).called(1);
  });

  test('withdrawing or unfollowing is its own request', () async {
    bloc.add(const UserProfileFollowUserRequested(userId: 'a', follow: false));
    await pumpEventQueue();
    verify(() => users.unfollow(unfollowId: 'a')).called(1);
    verifyNever(() => users.follow(followToId: any(named: 'followToId')));
  });

  test('after the pause, a change of mind goes through', () async {
    bloc.add(const UserProfileFollowUserRequested(userId: 'a'));
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    bloc.add(const UserProfileFollowUserRequested(userId: 'a', follow: false));
    await pumpEventQueue();
    verify(() => users.follow(followToId: 'a')).called(1);
    verify(() => users.unfollow(unfollowId: 'a')).called(1);
  });
}

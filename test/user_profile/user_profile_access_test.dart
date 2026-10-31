import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:treepnet/user_profile/user_profile.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockPostsRepository extends Mock implements PostsRepository {}

void main() {
  const me = 'me';
  const owner = 'owner';

  late _MockUserRepository users;
  late StreamController<User> profile;
  late StreamController<bool> blocked;
  late StreamController<bool> following;

  setUp(() {
    users = _MockUserRepository();
    profile = StreamController<User>.broadcast();
    blocked = StreamController<bool>.broadcast();
    following = StreamController<bool>.broadcast();
    when(() => users.currentUserId).thenReturn(me);
    when(() => users.profileScope(any())).thenReturn(SyncScope.none());
    when(() => users.profile(id: owner)).thenAnswer((_) => profile.stream);
    when(
      () => users.isBlocked(userId: owner, otherUserId: me),
    ).thenAnswer((_) => blocked.stream);
    when(
      () => users.followingStatus(userId: owner),
    ).thenAnswer((_) => following.stream);
  });

  tearDown(() async {
    await profile.close();
    await blocked.close();
    await following.close();
  });

  Future<UserProfileBloc> open() async {
    final bloc = UserProfileBloc(
      userRepository: users,
      postsRepository: _MockPostsRepository(),
      userId: owner,
    )..add(const UserProfileSubscriptionRequested());
    await pumpEventQueue();
    return bloc;
  }

  Future<ProfileAccess> after(UserProfileBloc bloc) async {
    await pumpEventQueue();
    return bloc.state.access;
  }

  test('loading until known — never the lock first', () async {
    final bloc = await open();
    expect(bloc.state.access, ProfileAccess.loading);
    profile.add(const User(id: owner, isPrivate: true));
    blocked.add(false);
    expect(await after(bloc), ProfileAccess.loading);
    following.add(true);
    expect(await after(bloc), ProfileAccess.visible);
    await bloc.close();
  });

  test('a private account the viewer does not follow is locked', () async {
    final bloc = await open();
    profile.add(const User(id: owner, isPrivate: true));
    blocked.add(false);
    following.add(false);
    expect(await after(bloc), ProfileAccess.locked);
    // Their request is accepted: it opens up.
    following.add(true);
    expect(await after(bloc), ProfileAccess.visible);
    await bloc.close();
  });

  test('a public account shows without waiting for the follow', () async {
    final bloc = await open();
    profile.add(const User(id: owner));
    blocked.add(false);
    expect(await after(bloc), ProfileAccess.visible);
    await bloc.close();
  });

  test('blocked by the owner is locked, even when public', () async {
    final bloc = await open();
    profile.add(const User(id: owner));
    following.add(true);
    blocked.add(true);
    expect(await after(bloc), ProfileAccess.locked);
    await bloc.close();
  });

  test("the user's own profile is visible from the start", () {
    final bloc = UserProfileBloc(
      userRepository: users,
      postsRepository: _MockPostsRepository(),
      userId: me,
    );
    expect(bloc.state.access, ProfileAccess.visible);
    unawaited(bloc.close());
  });
}

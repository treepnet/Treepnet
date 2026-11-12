import 'dart:async';

import 'package:authentication_client/authentication_client.dart';
import 'package:database_client/database_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_repository/user_repository.dart';

class _MockAuthenticationClient extends Mock implements AuthenticationClient {}

class _MockDatabaseClient extends Mock implements DatabaseClient {}

/// Guards the auth → profile stream.
///
/// It once used `asyncExpand`, which waits for each inner stream to complete
/// before handling the next auth event. The inner stream here is the profile
/// `watch()` — it never completes — so signing out was never delivered and the
/// app stayed logged in. `switchMap` drops the old profile watch instead.
void main() {
  late _MockAuthenticationClient authenticationClient;
  late _MockDatabaseClient databaseClient;
  late StreamController<AuthenticationUser> authUsers;
  late StreamController<User> profiles;

  const authUser = AuthenticationUser(id: 'abc', email: 'a@b.c');
  const profile = User(id: 'abc', username: 'hikmatcoder');

  setUp(() {
    authenticationClient = _MockAuthenticationClient();
    databaseClient = _MockDatabaseClient();
    authUsers = StreamController<AuthenticationUser>();
    // Broadcast so it stays open after the switch drops its listener, exactly
    // like the PowerSync watch it stands in for.
    profiles = StreamController<User>.broadcast();

    when(() => authenticationClient.user).thenAnswer((_) => authUsers.stream);
    when(
      () => databaseClient.profile(id: any(named: 'id')),
    ).thenAnswer((_) => profiles.stream);
  });

  tearDown(() async {
    await authUsers.close();
    await profiles.close();
  });

  UserRepository buildRepository() => UserRepository(
    databaseClient: databaseClient,
    authenticationClient: authenticationClient,
  );

  test('emits the identity first, then the profile row', () async {
    final emitted = <User>[];
    final subscription = buildRepository().user.listen(emitted.add);

    authUsers.add(authUser);
    await Future<void>.delayed(Duration.zero);
    profiles.add(profile);
    await Future<void>.delayed(Duration.zero);

    expect(emitted.length, 2);
    // The identity-only user has no handle yet — the profile carries it.
    expect(emitted.first.username, isNull);
    expect(emitted.last.username, 'hikmatcoder');
    await subscription.cancel();
  });

  test('delivers sign-out even though the profile watch never completes',
      () async {
    final emitted = <User>[];
    final subscription = buildRepository().user.listen(emitted.add);

    authUsers.add(authUser);
    await Future<void>.delayed(Duration.zero);
    profiles.add(profile);
    await Future<void>.delayed(Duration.zero);

    // Sign out. The profile stream is deliberately left open.
    authUsers.add(AuthenticationUser.anonymous);
    await Future<void>.delayed(Duration.zero);

    expect(
      emitted.last.isAnonymous,
      isTrue,
      reason: 'sign-out must reach AppBloc, or the app cannot leave the feed',
    );
    await subscription.cancel();
  });

  test('a late profile event cannot resurrect a signed-out user', () async {
    final emitted = <User>[];
    final subscription = buildRepository().user.listen(emitted.add);

    authUsers.add(authUser);
    await Future<void>.delayed(Duration.zero);
    authUsers.add(AuthenticationUser.anonymous);
    await Future<void>.delayed(Duration.zero);

    // The old watch fires once more after the switch — it must be ignored.
    profiles.add(profile);
    await Future<void>.delayed(Duration.zero);

    expect(emitted.last.isAnonymous, isTrue);
    await subscription.cancel();
  });

  group('one shared stream', () {
    test(
      'every read is the same stream, so screens share one chain',
      () async {
        final repository = buildRepository();
        expect(identical(repository.user, repository.user), isTrue);
        // (Listened to once, so tearDown's close completes.)
        await repository.user.listen((_) {}).cancel();
      },
    );

    test('a new listener gets the current user at once', () async {
      final repository = buildRepository();
      final first = repository.user.listen((_) {});
      authUsers.add(authUser);
      await Future<void>.delayed(Duration.zero);
      profiles.add(profile);
      await Future<void>.delayed(Duration.zero);

      // E.g. the owner's profile page, opened later.
      final late = <User>[];
      final second = repository.user.listen(late.add);
      await Future<void>.delayed(Duration.zero);
      expect(late.single.username, 'hikmatcoder');
      await second.cancel();
      await first.cancel();
    });

    test('one auth and profile chain, however many come and go', () async {
      var authListens = 0;
      authUsers.onListen = () => authListens++;
      final repository = buildRepository();

      for (var i = 0; i < 3; i++) {
        await repository.user.listen((_) {}).cancel();
      }
      final last = repository.user.listen((_) {});
      expect(authListens, 1);
      await last.cancel();
    });

    test('after main takes the first user, the profile still arrives', () async {
      // As at start-up: main reads user.first, which leaves the stream with
      // no listener; then the app listens. With rxdart's refCount the chain
      // never connected again, and the profile stayed the bare identity
      // ("Unknown", no avatar).
      when(() => authenticationClient.user).thenAnswer(
        (_) => Stream<AuthenticationUser>.multi((c) => c.add(authUser)),
      );
      final repository = buildRepository();
      // (Listened to once, so tearDown's close completes.)
      authUsers.stream.listen((_) {});

      final first = await repository.user.first;
      expect(first.username, isNull);
      await Future<void>.delayed(Duration.zero);

      final emitted = <User>[];
      final subscription = repository.user.listen(emitted.add);
      await Future<void>.delayed(Duration.zero);
      profiles.add(profile);
      await Future<void>.delayed(Duration.zero);

      expect(emitted.last.username, 'hikmatcoder');
      await subscription.cancel();
    });
  });
}

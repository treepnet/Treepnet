import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:treepnet/app/app.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockUserRepository users;

  setUp(() {
    users = _MockUserRepository();
    when(() => users.user).thenAnswer((_) => const Stream.empty());
    when(users.logOut).thenAnswer((_) async {});
    when(users.forgetServerSnapshots).thenReturn(null);
    when(() => users.currentUserId).thenReturn('me');
  });

  test('signs out even when a clean-up step fails '
      "(here the chat's secure storage: no plugin in tests)", () async {
    when(users.clearPushTokenOnServer).thenAnswer((_) async {});
    final bloc = AppBloc(
      user: const User(id: 'me'),
      userRepository: users,
    )..add(const AppLogoutRequested());
    await Future<void>.delayed(const Duration(seconds: 1));
    verify(users.logOut).called(1);
    await bloc.close();
  });

  test(
    'a server that never answers holds the sign-out ~5 s, not forever',
    () async {
      when(
        users.clearPushTokenOnServer,
      ).thenAnswer((_) => Completer<void>().future);
      final bloc = AppBloc(
        user: const User(id: 'me'),
        userRepository: users,
      )..add(const AppLogoutRequested());
      await Future<void>.delayed(const Duration(milliseconds: 6500));
      verify(users.logOut).called(1);
      await bloc.close();
    },
  );

  test('a second tap while signing out does nothing', () async {
    when(users.clearPushTokenOnServer).thenAnswer((_) async {});
    final bloc =
        AppBloc(
            user: const User(id: 'me'),
            userRepository: users,
          )
          ..add(const AppLogoutRequested())
          ..add(const AppLogoutRequested());
    await Future<void>.delayed(const Duration(seconds: 1));
    verify(users.logOut).called(1);
    await bloc.close();
  });
}

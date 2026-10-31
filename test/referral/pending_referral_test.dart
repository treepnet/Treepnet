import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:treepnet/referral/pending_referral.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// An invite is redeemed once, for the new account, and dropped only when the
/// server has answered — not when the phone was offline.
void main() {
  late _MockUserRepository users;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    users = _MockUserRepository();
    await PendingReferral.save('alice');
  });

  test('the server answered: the invite is used up', () async {
    when(
      () => users.redeemReferral(handle: 'alice'),
    ).thenAnswer((_) async => 'ok');
    await PendingReferral.redeemFor(users, userId: 'new-user');
    expect(await PendingReferral.read(), isNull);
  });

  test('offline at sign-up: kept, and finished later for that account',
      () async {
    when(
      () => users.redeemReferral(handle: 'alice'),
    ).thenThrow(Exception('no connection'));
    await PendingReferral.redeemFor(users, userId: 'new-user', attempts: 2);
    expect(await PendingReferral.read(), 'alice');

    // Another account on this phone doesn't get it.
    await PendingReferral.retryFor(users, 'someone-else');
    verify(() => users.redeemReferral(handle: 'alice')).called(2);

    when(
      () => users.redeemReferral(handle: 'alice'),
    ).thenAnswer((_) async => 'ok');
    await PendingReferral.retryFor(users, 'new-user');
    expect(await PendingReferral.read(), isNull);
  });

  test('"too late" is an answer too: the invite is dropped', () async {
    when(
      () => users.redeemReferral(handle: 'alice'),
    ).thenAnswer((_) async => 'too_late');
    await PendingReferral.redeemFor(users, userId: 'old-user');
    expect(await PendingReferral.read(), isNull);
  });
}

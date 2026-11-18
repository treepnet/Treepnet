import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:treepnet/settings/view/referral_badge.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// The checkmark after a name in every list (likers, story viewers, saved
/// and blocked profiles, search, comments, shared cards).
void main() {
  late _MockUserRepository users;

  setUp(() => users = _MockUserRepository());

  Future<void> pump(WidgetTester tester, {required double width}) =>
      tester.pumpWidget(
        RepositoryProvider<UserRepository>.value(
          value: users,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: const Align(
                    alignment: Alignment.centerLeft,
                    child: NameWithBadge(
                      userId: 'u1',
                      name: 'a_rather_long_username_here',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('a name with a checkmark earned', (tester) async {
    when(() => users.travelTierOf(userId: 'u1'))
        .thenAnswer((_) => Stream.value(2));
    await pump(tester, width: 400);
    await tester.pump();
    expect(find.text('a_rather_long_username_here'), findsOneWidget);
    expect(find.byType(VerificationBadge), findsOneWidget);
  });

  testWidgets('none earned: the name only', (tester) async {
    when(() => users.travelTierOf(userId: 'u1'))
        .thenAnswer((_) => Stream.value(0));
    await pump(tester, width: 400);
    await tester.pump();
    expect(find.text('a_rather_long_username_here'), findsOneWidget);
    expect(find.byType(VerificationBadge), findsNothing);
  });

  testWidgets('a long name is shortened, the checkmark stays', (tester) async {
    when(() => users.travelTierOf(userId: 'u1'))
        .thenAnswer((_) => Stream.value(3));
    await pump(tester, width: 120);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'no overflow');
    final badge = tester.getRect(find.byType(VerificationBadge));
    expect(badge.right, lessThanOrEqualTo(tester.getRect(find.byType(SizedBox).first).right + 0.5));
    expect(find.byType(VerificationBadge), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:treepnet/auth/login/login.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

void main() {
  testWidgets('"Done" right after the last key sends the whole password', (
    tester,
  ) async {
    final users = _MockUserRepository();
    when(
      () => users.logInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {});
    final cubit = LoginCubit(userRepository: users);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const Column(
              children: [UsernameTextField(), PasswordTextField()],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('loginPasswordTextField')),
      'secret12',
    );
    // No time passes: "Done" straight away (it used to wait 150 ms).
    await tester.enterText(find.byType(TextField).first, 'someone');
    await tester.showKeyboard(
      find.byKey(const ValueKey('loginPasswordTextField')),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    verify(
      () => users.logInWithPassword(email: 'someone', password: 'secret12'),
    ).called(1);
    await cubit.close();
  });
}

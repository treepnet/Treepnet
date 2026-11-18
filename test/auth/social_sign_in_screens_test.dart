import 'package:firebase_authentication_client/firebase_authentication_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:treepnet/app/services/fresh_account.dart';
import 'package:treepnet/auth/auth_error_text.dart';
import 'package:treepnet/auth/social/social_sign_in_buttons.dart';
import 'package:treepnet/auth/social/social_username_page.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

final _en = lookupAppLocalizations(const Locale('en'));

/// "Continue with Google / Apple" on the sign-in and sign-up screens, and
/// the username a new account picks.
void main() {
  late _MockUserRepository users;

  setUpAll(() => registerFallbackValue(SocialProvider.google));

  setUp(() {
    users = _MockUserRepository();
    when(() => users.currentUserId).thenReturn(null);
  });

  tearDown(FreshAccount.instance.end);

  /// [child] on a screen of its own: inside a scroll view for the buttons
  /// (as on the auth screens), as a whole page for a page.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    bool page = false,
  }) => tester.pumpWidget(
    RepositoryProvider<UserRepository>.value(
      value: users,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: page
            ? child
            : Scaffold(
                body: SingleChildScrollView(child: Center(child: child)),
              ),
      ),
    ),
  );

  void offer(Set<SocialProvider> providers) {
    for (final p in SocialProvider.values) {
      when(() => users.isSocialSignInAvailable(p))
          .thenReturn(providers.contains(p));
    }
  }

  group('the buttons', () {
    testWidgets('none set up: nothing at all, not even "Or"', (tester) async {
      offer({});
      await pump(tester, const SocialSignInButtons());
      expect(find.text(_en.orText), findsNothing);
      expect(find.text(_en.continueWithGoogleText), findsNothing);
    });

    testWidgets("Apple's comes first", (tester) async {
      offer({SocialProvider.google, SocialProvider.apple});
      await pump(tester, const SocialSignInButtons());
      final apple = tester.getTopLeft(find.text(_en.continueWithAppleText));
      final google = tester.getTopLeft(find.text(_en.continueWithGoogleText));
      expect(apple.dy, lessThan(google.dy));
    });

    testWidgets('a new account goes on to pick a username', (tester) async {
      offer({SocialProvider.google});
      when(() => users.signInWithSocial(SocialProvider.google)).thenAnswer(
        (_) async => const SocialNeedsUsername(
          ticket: 't',
          suggestedUsername: 'johnsmith',
        ),
      );
      await pump(tester, const SocialSignInButtons());
      await tester.tap(find.text(_en.continueWithGoogleText));
      await tester.pumpAndSettle();

      expect(find.byType(SocialUsernamePage), findsOneWidget);
      // Empty: no name is put in for the person.
      expect(find.text('johnsmith'), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, isEmpty);
    });

    testWidgets('a closed sheet: nothing happens, and it can be tapped again', (
      tester,
    ) async {
      offer({SocialProvider.google});
      when(() => users.signInWithSocial(SocialProvider.google))
          .thenThrow(const SocialSignInCanceled('closed'));
      await pump(tester, const SocialSignInButtons());
      await tester.tap(find.text(_en.continueWithGoogleText));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.continueWithGoogleText));
      await tester.pumpAndSettle();

      expect(find.byType(SocialUsernamePage), findsNothing);
      verify(() => users.signInWithSocial(SocialProvider.google)).called(2);
    });
  });

  group('the username', () {
    Future<void> submit(WidgetTester tester, String username) async {
      await pump(tester, const SocialUsernamePage(ticket: 'ticket-1'), page: true);
      await tester.enterText(find.byType(TextField), username);
      await tester.tap(find.text(_en.continueText));
      await tester.pumpAndSettle();
    }

    testWidgets('one that breaks the rules is said, and nothing is sent', (
      tester,
    ) async {
      await submit(tester, 'ab');
      expect(find.text(_en.usernameValidationText), findsOneWidget);
      verifyNever(
        () => users.completeSocialSignUp(
          ticket: any(named: 'ticket'),
          username: any(named: 'username'),
        ),
      );
    });

    testWidgets('a good one makes the account', (tester) async {
      when(
        () => users.completeSocialSignUp(ticket: 'ticket-1', username: 'johnsmith'),
      ).thenAnswer((_) async {});
      await submit(tester, 'johnsmith');
      verify(
        () => users.completeSocialSignUp(ticket: 'ticket-1', username: 'johnsmith'),
      ).called(1);
      // The router's "new account" wait (20 s, as after a password sign-up):
      // over before the test ends.
      expect(FreshAccount.instance.active, isTrue);
      FreshAccount.instance.end();
    });

    testWidgets('one taken meanwhile is said at the field', (tester) async {
      when(
        () => users.completeSocialSignUp(
          ticket: any(named: 'ticket'),
          username: any(named: 'username'),
        ),
      ).thenThrow(
        const SocialSignInFailure(
          AuthServiceError(message: 'taken', code: 'username_taken'),
        ),
      );
      await submit(tester, 'johnsmith');
      expect(find.text(_en.signUpUsernameTakenError), findsOneWidget);
      // Still here, to pick another.
      expect(find.byType(SocialUsernamePage), findsOneWidget);
    });
  });

  test('each Google/Apple refusal has its own text', () {
    SocialSignInFailure failure(String code) =>
        SocialSignInFailure(AuthServiceError(message: 'English', code: code));
    expect(
      socialSignInErrorText(_en, failure('wrong_account')),
      _en.socialSignInWrongAccountText,
    );
    expect(
      socialSignInErrorText(_en, failure('provider_unavailable')),
      _en.socialSignInUnavailableText,
    );
    expect(
      socialSignInErrorText(_en, failure('email_unverified')),
      _en.socialSignInNoEmailText,
    );
    expect(
      socialSignInErrorText(_en, failure('ticket_expired')),
      _en.socialSignInExpiredText,
    );
    // Google's or Apple's own sheet failing: no code, still a clear word.
    expect(
      socialSignInErrorText(_en, const SocialSignInFailure('sheet failed')),
      _en.socialSignInFailedText,
    );
  });
}

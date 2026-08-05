import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/onboarding/onboarding.dart';
import 'package:user_repository/user_repository.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// The intro is gated on `profiles.onboarded_at`, so the only thing that can
/// let someone out of it is that write landing. If it silently didn't happen,
/// the router would send them straight back here — a trap on first launch.
void main() {
  late _MockUserRepository userRepository;

  setUp(() {
    userRepository = _MockUserRepository();
    when(() => userRepository.completeOnboarding()).thenAnswer((_) async {});
  });

  Widget wrap() => RepositoryProvider<UserRepository>.value(
    value: userRepository,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OnboardingPage(),
    ),
  );

  testWidgets('opens on the first slide with Next, not Get started',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 1));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
    expect(find.text(l10n.onboardingNextText), findsOneWidget);
    expect(find.text(l10n.onboardingStartText), findsNothing);
  });

  testWidgets('Skip marks onboarding done', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 1));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.onboardingSkipText));
    await tester.pump();

    verify(() => userRepository.completeOnboarding()).called(1);
  });

  testWidgets('walking to the last slide and finishing marks it done',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 1));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Three taps of Next to reach the fourth (last) slide.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(l10n.onboardingNextText));
      await tester.pumpAndSettle();
    }

    expect(find.text(l10n.onboardingInviteTitle), findsOneWidget);
    // The label becomes the commit action only on the last slide.
    expect(find.text(l10n.onboardingStartText), findsOneWidget);
    verifyNever(() => userRepository.completeOnboarding());

    await tester.tap(find.text(l10n.onboardingStartText));
    await tester.pump();

    verify(() => userRepository.completeOnboarding()).called(1);
  });

  testWidgets('a double tap on Skip only writes once', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 1));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.onboardingSkipText));
    await tester.pump();
    // The button disables itself while the write is in flight; tapping the same
    // spot again must not queue a second write.
    await tester.tap(find.text(l10n.onboardingSkipText), warnIfMissed: false);
    await tester.pump();

    verify(() => userRepository.completeOnboarding()).called(1);
  });
}

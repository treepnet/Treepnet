import 'package:flutter/material.dart';
import 'package:treepnet/onboarding/view/visited_regions_page.dart';

/// {@template onboarding_page}
/// What a new account sees once, straight after signing up: pick the places
/// you have already been.
///
/// It used to open on a four-slide carousel explaining the app before getting
/// here. The slides were skipped more than read, and they delayed the one step
/// that actually does something — marking regions, which fills the travel map
/// in from day one instead of leaving it blank until the first post.
///
/// Finishing (or skipping) stamps `profiles.onboarded_at`, which is what the
/// router gates on, so this never shows twice — see [VisitedRegionsPage].
///
/// Shown in place rather than pushed as a route: while `needsOnboarding` is
/// true the router redirects every other location back here, and any AppBloc
/// emission rebuilds the stack, so an imperative push would be thrown away.
/// {@endtemplate}
class OnboardingPage extends StatelessWidget {
  /// {@macro onboarding_page}
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) => const VisitedRegionsPage();
}

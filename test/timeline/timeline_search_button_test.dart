import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:treepnet/app/app.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/timeline/timeline.dart';

/// Trends' search: no field on top any more, the magnifier at the top right
/// instead, where the feed has its bell.
void main() {
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: CustomScrollView(
              slivers: [
                // As on Trends.
                SliverAppBar(
                  floating: true,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 52,
                  actions: [TimelineSearchButton()],
                ),
                SliverToBoxAdapter(child: SizedBox(height: 2000)),
              ],
            ),
          ),
          routes: [
            GoRoute(
              name: AppRoutes.search.name,
              path: AppRoutes.search.name,
              builder: (context, state) =>
                  const Scaffold(body: Text('the search page')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
      ),
    );
    await tester.pump();
  }

  Finder magnifier() => find.descendant(
    of: find.byType(TimelineSearchButton),
    matching: find.byType(SvgPicture),
  );

  testWidgets("the magnifier at the top right, as the feed's bell", (
    tester,
  ) async {
    await pump(tester);
    final screen = tester.getSize(find.byType(Scaffold).first);
    final icon = tester.getRect(magnifier());
    expect(icon.size, const Size.square(AppSize.iconSizeMedium));
    // The bell's margin to the right edge.
    expect(icon.right, closeTo(screen.width - AppSpacing.md, 0.5));
    // In the middle of the 52-px bar.
    expect(icon.center.dy, closeTo(52 / 2, 0.5));
    expect(find.byType(TextField), findsNothing);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
  });

  testWidgets('a tap opens the search', (tester) async {
    await pump(tester);
    await tester.tap(magnifier());
    await tester.pumpAndSettle();
    expect(find.text('the search page'), findsOneWidget);
  });
}

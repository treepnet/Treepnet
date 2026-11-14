import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/widgets/user_profile_edit.dart';

/// The link prefix (`https://`) is decoration, not text: you cannot delete
/// it, the cursor never enters it, and — the part that actually bit — it must
/// not eat into the character budget.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('the prefix is shown but is not part of the value',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(
        ProfileInfoInput(
          value: '',
          label: 'Link',
          readOnly: false,
          infoType: ProfileEditInfoType.website,
          prefixText: 'https://',
          textController: controller,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 't.me/hikmatcoder');
    await tester.pump();

    // What gets stored is the address alone.
    expect(controller.text, 't.me/hikmatcoder');
    expect(controller.text.contains('https://'), isFalse);
    // And the prefix is on screen next to it.
    expect(find.text('https://'), findsOneWidget);
  });

  testWidgets('the counter measures the address, not the prefix',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(
        ProfileInfoInput(
          value: '',
          label: 'Link',
          readOnly: false,
          infoType: ProfileEditInfoType.website,
          prefixText: 'https://',
          textController: controller,
        ),
      ),
    );
    await tester.pump();

    // A link allows 100; the prefix must not show up as 8 of them.
    expect(find.text('0/100'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.text('3/100'), findsOneWidget);
  });

  testWidgets('each link field gets the limit its service allows',
      (tester) async {
    // A single 16 for everything used to cut real handles short.
    for (final (type, limit) in const [
      (ProfileEditInfoType.website, '0/100'),
      (ProfileEditInfoType.bio, '0/150'),
      (ProfileEditInfoType.fullName, '0/40'),
    ]) {
      await tester.pumpWidget(
        wrap(
          ProfileInfoInput(
            key: ValueKey(type),
            value: '',
            label: 'x',
            readOnly: false,
            infoType: type,
            textController: TextEditingController(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(limit), findsOneWidget, reason: 'wrong limit for $type');
    }
  });
}

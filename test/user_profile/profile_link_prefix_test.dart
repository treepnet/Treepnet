import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/user_profile/widgets/user_profile_edit.dart';

/// The link prefix (`t.me/`, `instagram.com/`, `https://`) is decoration, not
/// text: you cannot delete it, the cursor never enters it, and — the part that
/// actually bit — it must not eat into the character budget. `instagram.com/`
/// alone would have burned 14 of a 16-char field.
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
          label: 'Instagram',
          readOnly: false,
          infoType: ProfileEditInfoType.instagram,
          prefixText: 'instagram.com/',
          textController: controller,
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'hikmatcoder');
    await tester.pump();

    // What gets stored is the handle alone.
    expect(controller.text, 'hikmatcoder');
    expect(controller.text.contains('instagram.com/'), isFalse);
    // And the prefix is on screen next to it.
    expect(find.text('instagram.com/'), findsOneWidget);
  });

  testWidgets('the counter measures the handle, not the prefix',
      (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      wrap(
        ProfileInfoInput(
          value: '',
          label: 'Instagram',
          readOnly: false,
          infoType: ProfileEditInfoType.instagram,
          prefixText: 'instagram.com/',
          textController: controller,
        ),
      ),
    );
    await tester.pump();

    // Instagram allows 30; the prefix must not show up as 14 of them.
    expect(find.text('0/30'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(find.text('3/30'), findsOneWidget);
  });

  testWidgets('each link field gets the limit its service allows',
      (tester) async {
    // A single 16 for everything used to cut real handles short.
    for (final (type, limit) in const [
      (ProfileEditInfoType.telegram, '0/32'),
      (ProfileEditInfoType.instagram, '0/30'),
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

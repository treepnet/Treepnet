import 'package:flutter_test/flutter_test.dart';
import 'package:stories_editor/src/domain/providers/notifiers/text_editing_notifier.dart';

void main() {
  test('every text starts like the first: chip and size 25', () {
    final notifier = TextEditingNotifier();
    expect(notifier.textSize, storyTextSize);
    expect(notifier.backGroundColor, storyChipBackground);

    // After a text is added, or the tool cancelled.
    notifier
      ..textSize = 40
      ..setDefaults();
    expect(notifier.textSize, storyTextSize);
    expect(notifier.backGroundColor, storyChipBackground);
  });
}

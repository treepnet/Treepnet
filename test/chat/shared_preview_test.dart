import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/chat/chat_share_ref.dart';
import 'package:treepnet/l10n/l10n.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('a shared post or story is labelled in the app language', () {
    expect(sharedContentPreview(encodePostShare('p1'), ru), '📷 Пост');
    expect(sharedContentPreview(encodeStoryShare('s1'), ru), '📖 История');
    expect(sharedContentPreview(encodePostShare('p1'), en), '📷 Post');
    expect(sharedContentPreview(encodeStoryShare('s1'), en), '📖 Story');
  });

  test('plain text is not a share', () {
    expect(sharedContentPreview('salom', ru), isNull);
    expect(sharedContentPreview('treepnet:share:post:', ru), isNull);
  });
}

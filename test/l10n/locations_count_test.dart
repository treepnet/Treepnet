import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Under the author's name on every post: Russian has three plural forms, and
/// the word is lower case mid-line. 2-4 read "3 Локаций".
void main() {
  test('Russian place counts take the right form', () async {
    final ru = await AppLocalizations.delegate.load(const Locale('ru'));
    expect(ru.locationsCountText(1), '1 локация');
    expect(ru.locationsCountText(3), '3 локации');
    expect(ru.locationsCountText(5), '5 локаций');
    expect(ru.locationsCountText(11), '11 локаций');
    expect(ru.locationsCountText(21), '21 локация');
    expect(ru.locationsCountText(22), '22 локации');
  });

  test('English stays as it was', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.locationsCountText(1), '1 location');
    expect(en.locationsCountText(3), '3 locations');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/user_profile/user_profile.dart';

void main() {
  test('a link is stored without its scheme, the rest as typed', () {
    expect(bareLink('https://x.com'), 'x.com');
    expect(bareLink(' HTTP://www.x.com/a?b=1 '), 'www.x.com/a?b=1');
    expect(bareLink('t.me/someone'), 't.me/someone');
    expect(bareLink('   '), '');
  });
}

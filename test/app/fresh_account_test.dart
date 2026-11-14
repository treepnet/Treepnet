// fake_async comes with flutter_test.
// ignore_for_file: depend_on_referenced_packages

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treepnet/app/services/fresh_account.dart';

void main() {
  test('a new account is fresh for 20 s, or until sign-up fails', () {
    fakeAsync((time) {
      final fresh = FreshAccount.instance;
      var changes = 0;
      void count() => changes++;
      fresh
        ..addListener(count)
        ..start();
      expect(fresh.active, isTrue);

      time.elapse(const Duration(seconds: 19));
      expect(fresh.active, isTrue);
      time.elapse(const Duration(seconds: 2));
      expect(fresh.active, isFalse, reason: 'the feed, as before, after 20 s');

      fresh
        ..start()
        ..end();
      expect(fresh.active, isFalse);
      expect(changes, 4, reason: 'the router hears each change');
      fresh.removeListener(count);
    });
  });
}

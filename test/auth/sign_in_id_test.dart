import 'package:flutter_test/flutter_test.dart';
import 'package:form_fields/form_fields.dart';

SignInIdValidationError? _check(String value) =>
    SignInId.dirty(value).validator(value);

void main() {
  group('SignInId (the sign-in field)', () {
    test('takes an email', () {
      expect(_check('someone@example.com'), isNull);
    });

    test('takes any name the database allows, 3–16 characters', () {
      expect(_check('abc'), isNull);
      expect(_check('ab.c_12'), isNull);
      expect(_check('a' * 16), isNull);
    });

    test('takes an older 5-character name new sign-ups no longer can', () {
      expect(_check('hikma'), isNull);
      expect(Username.dirty('hikma').validator('hikma'), isNotNull);
    });

    test('refuses what can be neither', () {
      expect(_check(''), SignInIdValidationError.empty);
      expect(_check('ab'), SignInIdValidationError.invalid);
      expect(_check('a' * 17), SignInIdValidationError.invalid);
      expect(_check('no spaces'), SignInIdValidationError.invalid);
      expect(_check('half@email'), SignInIdValidationError.invalid);
    });
  });
}

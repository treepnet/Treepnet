import 'package:equatable/equatable.dart' show EquatableMixin;
import 'package:flutter/foundation.dart' show immutable;
import 'package:form_fields/src/email.dart';
import 'package:form_fields/src/formz_validation_mixin.dart';
import 'package:formz/formz.dart' show FormzInput;

/// {@template sign_in_id}
/// What someone signs in with: an email (it has an `@`) or a username.
///
/// Looser than `Username`, the rule for new names: an older account may have
/// a 3–5 character name (the database allows 3–16), and the server takes an
/// email too. The sign-in field used to turn both away before asking it.
/// {@endtemplate}
@immutable
class SignInId extends FormzInput<String, SignInIdValidationError>
    with EquatableMixin, FormzValidationMixin {
  /// {@macro sign_in_id}
  const SignInId.pure([super.value = '']) : super.pure();

  /// {@macro sign_in_id}
  const SignInId.dirty(super.value) : super.dirty();

  // Every name the database accepts (profiles username_length / _format).
  static final _usernameRegex = RegExp(r'^[a-z0-9_.]{3,16}$');

  @override
  SignInIdValidationError? validator(String value) {
    if (value.isEmpty) return SignInIdValidationError.empty;
    final ok = value.contains('@')
        ? Email.dirty(value).valid
        : _usernameRegex.hasMatch(value);
    return ok ? null : SignInIdValidationError.invalid;
  }

  @override
  Map<SignInIdValidationError?, String?> get validationErrorMessage => {
    SignInIdValidationError.empty: 'This field is required',
    SignInIdValidationError.invalid: 'Enter your username or email.',
    null: null,
  };

  @override
  List<Object?> get props => [value, pure];
}

/// Validation errors for [SignInId].
enum SignInIdValidationError {
  /// Nothing entered.
  empty,

  /// Neither an email nor a possible username.
  invalid,
}

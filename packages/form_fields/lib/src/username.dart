import 'package:equatable/equatable.dart' show EquatableMixin;
import 'package:flutter/foundation.dart' show immutable;
import 'package:form_fields/src/formz_validation_mixin.dart';
import 'package:formz/formz.dart' show FormzInput;

/// {@template name}
/// Form input for a name. It extends [FormzInput] and uses
/// [UsernameValidationError] for its validation errors.
/// {@endtemplate}
@immutable
class Username extends FormzInput<String, UsernameValidationError>
    with EquatableMixin, FormzValidationMixin {
  /// {@macro name.pure}
  const Username.pure([super.value = '']) : super.pure();

  /// {@macro name.dirty}
  const Username.dirty(super.value) : super.dirty();

  // Handles are lower-case only: they are matched exactly when signing in, so
  // allowing case would let `Hikmat` and `hikmat` look like different people.
  static final _nameRegex = RegExp(r'^[a-z0-9_.]{6,16}$');

  @override
  UsernameValidationError? validator(String value) {
    if (value.isEmpty) return UsernameValidationError.empty;
    if (!_nameRegex.hasMatch(value)) return UsernameValidationError.invalid;
    return null;
  }

  @override
  Map<UsernameValidationError?, String?> get validationErrorMessage => {
    UsernameValidationError.empty: 'This field is required',
    UsernameValidationError.invalid:
        'Username must be 6–16 characters: lower-case letters, numbers, '
        'periods and underscores only.',
    null: null,
  };

  @override
  List<Object?> get props => [value, pure];
}

/// Validation errors for [Username]. It can be empty or invalid.
enum UsernameValidationError {
  /// Empty name.
  empty,

  /// Invalid name.
  invalid,
}

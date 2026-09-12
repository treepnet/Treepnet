import 'package:flutter/widgets.dart';
import 'package:form_fields/form_fields.dart';
import 'package:treepnet/l10n/l10n.dart';

/// Maps a form field's validation error to a message in the app's CURRENT
/// language.
///
/// The `form_fields` package returns hard-coded English from its
/// `validationErrorMessage` maps, so the inline error under a text field would
/// always show English even when the app is set to Russian. These helpers
/// resolve the message from `context.l10n` at the point of display instead, so
/// login and sign-up field errors follow the app language like everything else.
///
/// Each takes the field's `validationError` (the enum, which is null unless the
/// input is dirty and invalid) and returns null when there is nothing to show.

String? passwordErrorText(BuildContext context, PasswordValidationError? error) {
  return switch (error) {
    null => null,
    PasswordValidationError.empty => context.l10n.requiredFieldText,
    // Keep in sync with Password.validator (min length 8).
    PasswordValidationError.invalid => context.l10n.passwordLengthErrorText(8),
  };
}

String? usernameErrorText(BuildContext context, UsernameValidationError? error) {
  return switch (error) {
    null => null,
    UsernameValidationError.empty => context.l10n.requiredFieldText,
    UsernameValidationError.invalid => context.l10n.usernameValidationText,
  };
}

String? emailErrorText(BuildContext context, EmailValidationError? error) {
  return switch (error) {
    null => null,
    EmailValidationError.empty => context.l10n.requiredFieldText,
    EmailValidationError.invalid => context.l10n.emailInvalidErrorText,
  };
}

String? otpErrorText(BuildContext context, OtpValidationError? error) {
  return switch (error) {
    null => null,
    OtpValidationError.empty => context.l10n.requiredFieldText,
    OtpValidationError.invalid => context.l10n.otpInvalidErrorText,
  };
}

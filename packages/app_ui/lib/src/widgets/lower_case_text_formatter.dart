import 'package:flutter/services.dart';

/// Forces every keystroke to lower case — usernames are always lower case, so
/// capitals can never be typed in the first place.
class LowerCaseTextFormatter extends TextInputFormatter {
  /// {@macro lower_case_text_formatter}
  const LowerCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}

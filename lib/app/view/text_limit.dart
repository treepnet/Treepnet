import 'package:flutter/material.dart';

/// The longest post caption and comment the app takes (the server allows a
/// little more: it counts code points, and an emoji can be several).
const kCaptionMaxLength = 2200;
const kCommentMaxLength = 1000;

/// A field's "how much is left" — only once it gets close to the limit, so a
/// short comment doesn't carry a "12/1000" under it.
Widget? nearLimitCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) {
  if (maxLength == null || maxLength - currentLength > 100) return null;
  return Text(
    '${maxLength - currentLength}',
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: currentLength >= maxLength ? Colors.redAccent : Colors.white54,
    ),
  );
}

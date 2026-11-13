import 'package:flutter/material.dart';

/// The longest post caption and comment the app takes (the server allows a
/// little more: it counts code points, and an emoji can be several).
const kCaptionMaxLength = 2200;
const kCommentMaxLength = 1000;

/// A story highlight's name, and the name a place is given on the map (the
/// server allows several times these, migration 016).
const kHighlightNameMaxLength = 30;
const kPlaceNameMaxLength = 100;

/// A field's "how much is left" — only once it gets close to the limit, so a
/// short comment doesn't carry a "12/1000" under it.
/// No counter at all: for short names, where the limit just stops the typing.
Widget? noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

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

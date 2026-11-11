/// Merging the first page the server sends when a thread reconnects into what
/// the thread already shows. Messages are newest first.
library;

/// The thread after a reconnect: [current] (what is on screen, newest first)
/// with [page] (the server's newest page) merged in.
///
/// A message already shown is replaced by the server's copy (it may have
/// been edited or deleted meanwhile); one still being sent (no id yet) is
/// replaced by the server's copy with the same key; new ones go on top.
///
/// When none of the page's messages is on screen yet, more arrived than one
/// page holds (or the screen showed what was saved on the phone): merging
/// would leave a hole between the page and the older messages, unseen. The
/// thread then becomes the page, plus what is still being sent, and `gap` is
/// true: the caller takes the page's paging too, so scrolling up loads the
/// rest.
({List<T> messages, bool gap}) mergeOnlinePage<T>({
  required List<T> current,
  required List<T> page,
  required String Function(T message) idOf,
  required String Function(T message) keyOf,
}) {
  bool isLocal(T message) => idOf(message).isEmpty;
  final indexById = <String, int>{
    for (final (index, message) in current.indexed)
      if (!isLocal(message)) idOf(message): index,
  };
  final pageKeys = {
    for (final message in page)
      if (keyOf(message).isNotEmpty) keyOf(message),
  };

  final overlaps = page.any((message) => indexById.containsKey(idOf(message)));
  if (!overlaps && indexById.isNotEmpty) {
    return (
      messages: [
        for (final message in current)
          if (isLocal(message) && !pageKeys.contains(keyOf(message))) message,
        ...page,
      ],
      gap: true,
    );
  }

  final merged = [...current];
  final localByKey = <String, int>{
    for (final (index, message) in current.indexed)
      if (isLocal(message) && keyOf(message).isNotEmpty) keyOf(message): index,
  };
  final shown = indexById.keys.toSet();
  final added = <T>[];
  for (final message in page) {
    final localIndex = keyOf(message).isEmpty
        ? null
        : localByKey[keyOf(message)];
    if (localIndex != null) {
      merged[localIndex] = message;
      shown.add(idOf(message));
      continue;
    }
    final knownIndex = indexById[idOf(message)];
    if (knownIndex != null) {
      merged[knownIndex] = message;
      continue;
    }
    if (shown.add(idOf(message))) added.add(message);
  }
  return (messages: [...added, ...merged], gap: false);
}

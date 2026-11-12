/// The peer's "read" marks on a thread. Messages are identified by their
/// server id; one still being sent, or that failed, has none yet.
library;

/// [messages] with [asRead] applied to those the peer has read: every one the
/// server has (or only [id], when given). A message still being sent, or
/// that failed, is left as it is: it used to turn ✓✓ "read" when the peer
/// opened the thread, its Retry/Delete gone, as if it had arrived.
List<T> markRead<T>(
  List<T> messages, {
  required String Function(T message) idOf,
  required T Function(T message) asRead,
  String? id,
}) => [
  for (final message in messages)
    idOf(message).isEmpty || (id != null && idOf(message) != id)
        ? message
        : asRead(message),
];

/// Whether an update to a message the peer has already read keeps showing it
/// read. Only for the server's copy: a local update (still sending, or the
/// send failed) shows its own state, or a failure under ✓✓ couldn't show.
bool keepsRead({required bool wasRead, required bool updateIsLocal}) =>
    wasRead && !updateIsLocal;

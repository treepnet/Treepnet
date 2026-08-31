/// A shared post/story carried inside a chat message.
///
/// Shares are sent as ordinary TEXT messages whose content is a sentinel string
/// (so the chat backend stays unchanged — no media is duplicated, only the
/// post/story id travels). The chat thread recognises the sentinel and renders
/// a rich card instead of plain text (see `sharedMessageBuilder`).
library;

enum SharedRefKind { post, story }

class SharedRef {
  const SharedRef({required this.kind, required this.id});

  final SharedRefKind kind;
  final String id;
}

const _prefix = 'treepnet:share:';

String encodePostShare(String postId) => '${_prefix}post:$postId';

String encodeStoryShare(String storyId) => '${_prefix}story:$storyId';

/// Decodes a message's content into a [SharedRef], or `null` if it isn't a
/// share sentinel (i.e. it is plain text).
SharedRef? parseSharedRef(String content) {
  if (!content.startsWith(_prefix)) return null;
  final rest = content.substring(_prefix.length);
  final sep = rest.indexOf(':');
  if (sep <= 0) return null;
  final kind = switch (rest.substring(0, sep)) {
    'post' => SharedRefKind.post,
    'story' => SharedRefKind.story,
    _ => null,
  };
  final id = rest.substring(sep + 1);
  if (kind == null || id.isEmpty) return null;
  return SharedRef(kind: kind, id: id);
}

import 'package:shared/shared.dart';

/// Orders two authors for the Stories tab, comparing their story lists.
///
/// Anyone with something you haven't watched comes first; inside each group the
/// most recently posted story wins. Feed it to `List.sort`.
///
/// Ordering used to follow the `subscriptions` table — i.e. whoever you
/// happened to follow first — so a story from a minute ago could sit below a
/// twenty-hour-old one, and watching something never moved it out of the way.
///
/// Both lists are assumed non-empty: an author with no live stories has no card
/// in the grid to place.
int compareStoryAuthors(List<Story> a, List<Story> b) {
  final aSeen = a.every((story) => story.seen);
  final bSeen = b.every((story) => story.seen);
  if (aSeen != bSeen) return aSeen ? 1 : -1;
  return newestStoryAt(b).compareTo(newestStoryAt(a));
}

/// When the freshest story in [stories] was posted.
DateTime newestStoryAt(List<Story> stories) => stories
    .map((story) => story.createdAt)
    .reduce((a, b) => a.isAfter(b) ? a : b);

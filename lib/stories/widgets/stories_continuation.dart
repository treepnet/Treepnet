import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:treepnet/stories/widgets/stories_props.dart';
import 'package:user_repository/user_repository.dart';

/// Rolls the viewer on to the next profile in the Stories tab.
///
/// The run stops as soon as the next profile's seen state differs from the one
/// the user opened on: start on an unseen profile and you keep going through
/// unseen profiles, hit a seen one and the viewer closes back to the grid.
/// Start on a seen profile and the mirror applies.
///
/// That works as a plain forward walk because the grid is already ordered
/// unseen-first, then seen (see `compareStoryAuthors`), so the boundary is
/// crossed exactly once.
///
/// [startedUnseen] is captured at push time on purpose. By the time the first
/// profile finishes it has become seen, so recomputing it here would flip the
/// mode on the very first hop.
StoriesContinuation nextProfileContinuation({
  required StoriesRepository storiesRepository,
  required List<User> authors,
  required int fromIndex,
  required String viewerId,
  required bool startedUnseen,
}) {
  return () async {
    final cursor = fromIndex + 1;
    if (cursor >= authors.length) return null;
    final author = authors[cursor];

    // `.first` on the merged stream, not a cached snapshot: the local
    // seen-stories store is seeded asynchronously, so a snapshot taken too
    // early reports everything as unseen.
    final stories = await storiesRepository
        .mergedStories(authorId: author.id, userId: viewerId)
        .first;
    if (stories.isEmpty) return null;

    final unseen = stories.any((story) => !story.seen);
    // The boundary between the unseen run and the seen run — stop here.
    if (unseen != startedUnseen) return null;

    return StoriesProps(
      stories: stories,
      author: author,
      continuation: nextProfileContinuation(
        storiesRepository: storiesRepository,
        authors: authors,
        fromIndex: cursor,
        viewerId: viewerId,
        startedUnseen: startedUnseen,
      ),
    );
  };
}

/// Rolls the viewer on to the next highlight cover on a profile.
///
/// No seen/unseen rule here — highlights are an archive the owner curated, not
/// a feed, so it simply plays the row left to right and closes at the end.
StoriesContinuation nextHighlightContinuation({
  required StoriesRepository storiesRepository,
  required List<StoryHighlight> highlights,
  required int fromIndex,
}) {
  return () async {
    final cursor = fromIndex + 1;
    if (cursor >= highlights.length) return null;
    final highlight = highlights[cursor];

    final stories = await storiesRepository
        .highlightStoriesOf(highlightId: highlight.id)
        .first;
    if (stories.isEmpty) return null;

    return StoriesProps(
      stories: stories,
      author: stories.first.author,
      continuation: nextHighlightContinuation(
        storiesRepository: storiesRepository,
        highlights: highlights,
        fromIndex: cursor,
      ),
    );
  };
}

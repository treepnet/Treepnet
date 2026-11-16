import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// Supplies whatever should play once the current stories run out.
///
/// Returning `null` closes the viewer. Kept as a callback rather than a list of
/// authors because "what comes next" differs per entry point: the Stories tab
/// walks profiles and stops when the seen/unseen run ends, while a profile's
/// highlights simply step to the next cover. The rule lives at the call site,
/// which is where the surrounding list already is.
typedef StoriesContinuation = Future<StoriesProps?> Function();

class StoriesProps {
  const StoriesProps({
    required this.stories,
    required this.author,
    this.continuation,
    this.previous,
  });

  final User author;
  final List<Story> stories;

  /// Null (the default) means the viewer closes when the stories end — which is
  /// what the archive and map entry points want.
  final StoriesContinuation? continuation;

  /// What comes before these stories in the list they were opened from (the
  /// Stories tab's previous profile, a profile's previous highlight): a back
  /// tap on the first story goes there, whether or not it was watched on the
  /// way. Null: that tap starts the first story over.
  final StoriesContinuation? previous;
}

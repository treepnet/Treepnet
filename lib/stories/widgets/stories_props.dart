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
  });

  final User author;
  final List<Story> stories;

  /// Null (the default) means the viewer closes when the stories end — which is
  /// what the archive and map entry points want.
  final StoriesContinuation? continuation;
}

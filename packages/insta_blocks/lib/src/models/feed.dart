import 'package:equatable/equatable.dart';
import 'package:insta_blocks/insta_blocks.dart';

/// {@template feed}
/// Represents a page of feed data containing [Feed] blocks, the page number,
/// and whether there are more pages to load.
///
/// This is used to paginate feed requests and data.
/// {@endtemplate}
class Feed extends Equatable {
  /// {@macro feed}
  const Feed({required this.feedPage});

  /// {@macro feed.empty}
  const Feed.empty()
    : this(feedPage: const FeedPage.empty());

  /// The current feed page inside [Feed].
  final FeedPage feedPage;

  @override
  List<Object?> get props => [feedPage];

  /// Copies the current [Feed] instance and overrides the provided
  /// properties.
  Feed copyWith({FeedPage? feedPage}) {
    return Feed(feedPage: feedPage ?? this.feedPage);
  }
}

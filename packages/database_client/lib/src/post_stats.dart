import 'package:flutter/foundation.dart' show immutable;

/// What a post card shows around the post: its counts, the viewer's state and
/// two things about the author. Read for every post on screen in one live
/// query (`DatabaseClient.postStatsOf`) — a card used to open five queries of
/// its own, plus two in its header.
@immutable
class PostStats {
  /// Creates a [PostStats].
  const PostStats({
    required this.likes,
    required this.comments,
    required this.isLiked,
    required this.isBookmarked,
    required this.isAuthorFollowed,
    required this.authorTier,
    required this.authorPlaces,
  });

  /// Likes on the post.
  final int likes;

  /// Comments on the post, leaving out people blocked either way.
  final int comments;

  /// Whether the viewer liked it.
  final bool isLiked;

  /// Whether the viewer saved it.
  final bool isBookmarked;

  /// Whether the viewer follows the author (an accepted follow).
  final bool isAuthorFollowed;

  /// The author's travel tier badge, 0 for none or an expired one (as
  /// `travelTierOf`).
  final int authorTier;

  /// How many of the author's posts have a location (the "N locations" under
  /// their name).
  final int authorPlaces;

  @override
  bool operator ==(Object other) =>
      other is PostStats &&
      other.likes == likes &&
      other.comments == comments &&
      other.isLiked == isLiked &&
      other.isBookmarked == isBookmarked &&
      other.isAuthorFollowed == isAuthorFollowed &&
      other.authorTier == authorTier &&
      other.authorPlaces == authorPlaces;

  @override
  int get hashCode => Object.hash(
    likes,
    comments,
    isLiked,
    isBookmarked,
    isAuthorFollowed,
    authorTier,
    authorPlaces,
  );
}

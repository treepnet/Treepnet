/// {@template post_removal}
/// Posts that just left the signed-in user's view: one they deleted, hid
/// ("Don't show again") or archived ([postId]), or every post of an author
/// they blocked ([authorId]).
///
/// The home feed updates itself; screens that keep their own copy of posts (a
/// feed opened from a grid, a single post, the Trends grid) drop them on this,
/// wherever the action was taken. They used to keep showing them: a like on
/// a deleted post was refused, and a blocked person's photos stayed in view.
/// {@endtemplate}
class PostRemoval {
  /// {@macro post_removal} One post.
  const PostRemoval.post(String this.postId) : authorId = null;

  /// {@macro post_removal} Every post by [authorId].
  const PostRemoval.author(String this.authorId) : postId = null;

  /// The post that went, when it is one post.
  final String? postId;

  /// The author whose posts went, when it is a block.
  final String? authorId;

  /// Whether the post [postId] by [authorId] is one of those that went.
  bool removes({required String postId, required String authorId}) =>
      (this.postId != null && this.postId == postId) ||
      (this.authorId != null && this.authorId == authorId);

  @override
  bool operator ==(Object other) =>
      other is PostRemoval &&
      other.postId == postId &&
      other.authorId == authorId;

  @override
  int get hashCode => Object.hash(postId, authorId);

  @override
  String toString() => postId != null
      ? 'PostRemoval.post($postId)'
      : 'PostRemoval.author($authorId)';
}

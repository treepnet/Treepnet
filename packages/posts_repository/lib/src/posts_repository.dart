import 'package:database_client/database_client.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// {@template posts_repository}
/// A package that manages posts flow.
/// {@endtemplate}
class PostsRepository implements PostsBaseRepository {
  /// {@macro posts_repository}
  const PostsRepository({required DatabaseClient databaseClient})
    : _databaseClient = databaseClient;

  final DatabaseClient _databaseClient;

  @override
  Future<List<Post>> getPage({
    required int offset,
    required int limit,
    bool onlyReels = false,
  }) => _databaseClient.getPage(
    offset: offset,
    limit: limit,
    onlyReels: onlyReels,
  );

  @override
  Future<void> like({
    required String id,
    bool post = true,
  }) => _databaseClient.like(id: id, post: post);

  @override
  Future<Post?> createPost({
    required String id,
    required String caption,
    required String media,
    String? location,
    String? locationCountry,
    String? locationRegion,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) => _databaseClient.createPost(
    id: id,
    caption: caption,
    media: media,
    location: location,
    locationCountry: locationCountry,
    locationRegion: locationRegion,
    locationName: locationName,
    locationLat: locationLat,
    locationLng: locationLng,
  );

  /// Broadcasts the exact `(lat, lng)` of every post by [userId] that has a
  /// picked location — one map marker per post.
  Stream<List<({double lat, double lng, String? name})>> visitedPointsOf({
    required String userId,
  }) => _databaseClient.visitedPointsOf(userId: userId);

  @override
  Stream<List<({double lat, double lng, String? name})>> storyPointsOf({
    required String userId,
  }) => _databaseClient.storyPointsOf(userId: userId);

  @override
  Stream<Set<String>> visitedRegionsOf({required String userId}) =>
      _databaseClient.visitedRegionsOf(userId: userId);

  /// Broadcasts a map of ISO 3166-2 region code to the number of posts [userId]
  /// has placed there, used to shade the travel map by density.
  Stream<Map<String, int>> visitedRegionCountsOf({required String userId}) =>
      _databaseClient.visitedRegionCountsOf(userId: userId);

  /// Regions the user explicitly marked as visited (onboarding / profile).
  Stream<Set<String>> markedRegionsOf({required String userId}) =>
      _databaseClient.markedRegionsOf(userId: userId);

  /// Replaces the user's marked regions.
  Future<void> setVisitedRegions({
    required String userId,
    required Set<String> regionIsos,
  }) => _databaseClient.setVisitedRegions(
    userId: userId,
    regionIsos: regionIsos,
  );

  @override
  Future<String?> deletePost({required String id}) =>
      _databaseClient.deletePost(id: id);

  @override
  Stream<bool> isLiked({
    required String id,
    String? userId,
    bool post = true,
  }) => _databaseClient.isLiked(id: id, userId: userId, post: post);

  @override
  Stream<int> likesOf({required String id, bool post = true}) =>
      _databaseClient.likesOf(id: id, post: post);

  @override
  Future<void> bookmarkPost({required String postId}) =>
      _databaseClient.bookmarkPost(postId: postId);

  @override
  Stream<bool> isBookmarked({required String postId, String? userId}) =>
      _databaseClient.isBookmarked(postId: postId, userId: userId);

  @override
  Future<List<Post>> getSavedPosts({required int offset, required int limit}) =>
      _databaseClient.getSavedPosts(offset: offset, limit: limit);

  @override
  Future<void> archivePost({required String postId}) =>
      _databaseClient.archivePost(postId: postId);

  @override
  Stream<bool> isArchived({required String postId, String? userId}) =>
      _databaseClient.isArchived(postId: postId, userId: userId);

  @override
  Future<List<Post>> getArchivedPosts({
    required int offset,
    required int limit,
  }) => _databaseClient.getArchivedPosts(offset: offset, limit: limit);

  @override
  Stream<int> postsAmountOf({required String userId}) =>
      _databaseClient.postsAmountOf(userId: userId);

  @override
  Stream<List<Post>> postsOf({String? userId, int? limit}) =>
      _databaseClient.postsOf(userId: userId, limit: limit);

  @override
  Stream<List<Post>> postsInRegion({
    required String userId,
    required String iso,
  }) => _databaseClient.postsInRegion(userId: userId, iso: iso);

  @override
  Stream<List<Post>> postsAtPoint({
    required String userId,
    required double lat,
    required double lng,
    double radiusDegrees = 0.02,
  }) => _databaseClient.postsAtPoint(
    userId: userId,
    lat: lat,
    lng: lng,
    radiusDegrees: radiusDegrees,
  );

  @override
  Future<Post?> updatePost({
    required String id,
    String? caption,
  }) => _databaseClient.updatePost(id: id, caption: caption);

  @override
  Stream<int> commentsAmountOf({required String postId}) =>
      _databaseClient.commentsAmountOf(postId: postId);

  @override
  Stream<List<Comment>> commentsOf({required String postId}) =>
      _databaseClient.commentsOf(postId: postId);

  @override
  Future<void> createComment({
    required String content,
    required String postId,
    required String userId,
    String? repliedToCommentId,
  }) => _databaseClient.createComment(
    content: content,
    postId: postId,
    userId: userId,
    repliedToCommentId: repliedToCommentId,
  );

  @override
  Future<void> deleteComment({required String id}) =>
      _databaseClient.deleteComment(id: id);

  @override
  Stream<List<Comment>> repliedCommentsOf({required String commentId}) =>
      _databaseClient.repliedCommentsOf(commentId: commentId);

  @override
  Future<void> sharePost({
    required String id,
    required User sender,
    required User receiver,
    required Message sharedPostMessage,
    Message? message,
    PostAuthor? postAuthor,
  }) => _databaseClient.sharePost(
    id: id,
    sender: sender,
    sharedPostMessage: sharedPostMessage,
    message: message,
    receiver: receiver,
    postAuthor: postAuthor,
  );

  @override
  Future<Post?> getPostBy({required String id}) =>
      _databaseClient.getPostBy(id: id);

  @override
  Future<List<User>> getPostLikers({
    required String postId,
    int limit = 30,
    int offset = 0,
  }) => _databaseClient.getPostLikers(
    postId: postId,
    limit: limit,
    offset: offset,
  );

  @override
  Future<List<User>> getPostLikersInFollowings({
    required String postId,
    int limit = 3,
    int offset = 0,
  }) => _databaseClient.getPostLikersInFollowings(
    postId: postId,
    limit: limit,
    offset: offset,
  );

  /// Returns a list of recommended posts.
  static final recommendedPosts = <PostLargeBlock>[];
}

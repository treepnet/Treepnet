import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:database_client/src/invite_badge.dart';
import 'package:database_client/src/comment_stats.dart';
import 'package:database_client/src/post_stats.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// User base repository.
abstract class UserBaseRepository {
  /// The id of the currently authenticated user.
  String? get currentUserId;

  /// Broadcasts the user profile identified by [id].
  Stream<User> profile({required String id});

  /// The public profile (name, username, avatar) of each of [ids], live, from
  /// one query — keyed by id; ids not on this device are left out.
  Stream<Map<String, User>> profilesOf({required List<String> ids});

  /// Clears the signed-in user's push token on the server right away, not
  /// through the local upload queue (which signing out wipes).
  Future<void> clearPushTokenOnServer();

  /// Updates currently authenticated database user's metadata.
  Future<void> updateUser({
    String? fullName,
    String? email,
    String? username,
    String? avatarUrl,
    String? pushToken,
    String? bio,
    String? birthday,
    String? telegram,
    String? website,
    String? instagram,
    String? gender,
    String? lang,
    bool clearAvatar = false,
  });

  /// Updates the [bio] ("About") text of the profile identified by [userId],
  /// writing straight to the `profiles` table (PowerSync uploads the change).
  Future<void> updateUserBio({required String userId, required String bio});

  /// Marks the intro as seen for the current user.
  Future<void> completeOnboarding();

  /// Blocks [blockedId] on behalf of [userId].
  Future<void> blockUser({required String userId, required String blockedId});

  /// Unblocks [blockedId] on behalf of [userId].
  Future<void> unblockUser({required String userId, required String blockedId});

  /// Whether [userId] has blocked [otherUserId].
  Stream<bool> isBlocked({
    required String userId,
    required String otherUserId,
  });

  /// Streams the profiles [userId] has blocked, newest first.
  Stream<List<User>> blockedUsers({required String userId});

  /// Streams the ids of everyone [userId] blocked or was blocked by.
  Stream<Set<String>> blockedPeersOf({required String userId});

  /// Changes the currently authenticated user's password to [newPassword].
  Future<void> changePassword({required String newPassword});

  /// Sets whether the profile identified by [userId] is [isPrivate].
  Future<void> updatePrivacy({
    required String userId,
    required bool isPrivate,
  });

  /// Follows to the user by provided [followToId]. [followerId] is the id
  /// of currently authenticated user.
  Future<void> follow({
    required String followToId,
    String? followerId,
  });

  /// Unfollow from user profile, identified by [unfollowId].
  Future<void> unfollow({required String unfollowId, String? unfollowerId});

  /// Removes follower from followers of current users.
  Future<void> removeFollower({required String id});

  /// Check if the user identified by [followerId] is followed to
  /// the user identified by [userId].
  Future<bool> isFollowed({
    required String userId,
    String? followerId,
  });

  /// Returns realtime stream of followings status of the user identified by
  /// [followerId] to the user identified by [userId]. Only an *accepted*
  /// follow counts — a pending request is not "following" for gating purposes.
  Stream<bool> followingStatus({
    required String userId,
    String? followerId,
  });

  /// Realtime relationship of [followerId] to [userId], one of `none`,
  /// `pending` (a follow request awaiting approval) or `accepted`.
  Stream<String> followState({required String userId, String? followerId});

  /// Approves the pending follow request from [requesterId] to the current
  /// user, turning it into an accepted follow.
  Future<void> acceptFollowRequest({required String requesterId});

  /// Rejects and removes the pending follow request from [requesterId].
  Future<void> declineFollowRequest({required String requesterId});

  /// Returns followings count of the user identified by [userId].
  Stream<int> followersCountOf({required String userId});

  /// Returns count of followings of the user identified by [userId].
  Stream<int> followingsCountOf({required String userId});

  /// Returns a list of followers of the user identified by [userId].
  Future<List<User>> getFollowers({String? userId});

  /// Returns a list of followings of the user identified by [userId].
  ///
  /// [limit] caps how many are fetched (for scroll pagination); null = all.
  Future<List<User>> getFollowings({String? userId, int? limit});

  /// Broadcasts a list of followers of the user identified by [userId].
  ///
  /// [limit] caps the reactive window (for scroll pagination); null = all.
  Stream<List<User>> followers({required String userId, int? limit});

  /// Looks up into a database a returns users associated with the provided
  /// [query].
  Future<List<User>> searchUsers({
    required int limit,
    required int offset,
    required String? query,
    String? userId,
    String? excludeUserIds,
  });

  /// People the current user does not follow yet — the "Discover people"
  /// suggestions. Excludes the current user and everyone they already follow.
  Future<List<User>> suggestedUsers({int limit = 50});

  /// Realtime count of people the user identified by [userId] has referred.
  Stream<int> referralCountOf({required String userId});

  /// Realtime highest reward tier (0..6) earned by the user identified by
  /// [userId].
  Stream<int> referralTierOf({required String userId});

  /// The user's verification badge tier, 0-6 — earned purely by inviting
  /// people, per [kInviteBadgeRungs]. See [inviteBadgeStatusOf] for the full
  /// picture (expiry, progress).
  Stream<int> travelTierOf({required String userId});

  /// Live badge state for the invite screen: invites, tier, expiry, next rung.
  Stream<InviteBadgeStatus> inviteBadgeStatusOf({required String userId});

  /// ISO 3166-2 codes the user explicitly marked as visited (onboarding /
  /// profile) — as opposed to [visitedRegionsOf], which derives them from
  /// posts.
  Stream<Set<String>> markedRegionsOf({required String userId});

  /// The user's story highlights, newest first.
  Stream<List<StoryHighlight>> storyHighlightsOf({required String userId});

  /// Stories inside a highlight, oldest first (playback order).
  Stream<List<Story>> highlightStoriesOf({required String highlightId});

  /// Creates a highlight from [storyIds]; the first story becomes the cover.
  Future<void> createStoryHighlight({
    required String userId,
    required String name,
    required List<String> storyIds,
    String? coverUrl,
  });

  /// Removes a highlight and its items.
  Future<void> deleteStoryHighlight({required String highlightId});

  /// Adds an existing [storyId] to an existing highlight; a no-op if it is
  /// already in there.
  Future<void> addStoryToHighlight({
    required String highlightId,
    required String storyId,
  });

  /// Sets a story's own location columns so it appears on the owner's map at
  /// the pinned place (the map reads the `stories` row, not `location_stories`).
  Future<void> setStoryLocation({
    required String storyId,
    required double lat,
    required double lng,
    String? name,
  });

  /// Whether [storyId] is pinned anywhere — to a place or inside a highlight.
  Future<bool> isStoryPinned({required String storyId});

  /// Removes [storyId] from every place and highlight, and clears its own map
  /// location — but keeps the story row itself.
  Future<void> unpinStoryEverywhere({required String storyId});

  /// Profiles [userId] has saved (bookmarked), newest first.
  Stream<List<User>> savedProfilesOf({required String userId});

  /// Whether [userId] has saved [profileId].
  Stream<bool> isProfileSaved({
    required String userId,
    required String profileId,
  });

  /// Saves [profileId] to [userId]'s saved profiles.
  Future<void> saveProfile({
    required String userId,
    required String profileId,
  });

  /// Removes [profileId] from [userId]'s saved profiles.
  Future<void> unsaveProfile({
    required String userId,
    required String profileId,
  });

  /// Replaces the user's marked regions with [regionIsos].
  Future<void> setVisitedRegions({
    required String userId,
    required Set<String> regionIsos,
  });

  /// Realtime activity feed for [userId]: likes and comments on their posts and
  /// new followers, newest first.
  Stream<List<NotificationItem>> notificationsOf({required String userId});

  /// How many of those arrived since [markNotificationsSeen] was last called.
  ///
  /// Notifications are synthesised from other tables and have no read flag, so
  /// this is a timestamp comparison against `profiles.notifications_seen_at`.
  Stream<int> unreadNotificationsCount({required String userId});

  /// Moves the watermark to now, clearing the notification badge.
  Future<void> markNotificationsSeen({required String userId});

  /// Records that the current user was invited via [handle] (a username or
  /// user id from an invite link). Returns a status: `ok` (recorded),
  /// `already` (you were already invited), `self` (your own code), or
  /// `unknown` (no such user).
  Future<String> redeemReferral({required String handle});

  /// Presence heartbeat: stamps `profiles.last_seen_at` for [userId] = now.
  Future<void> updatePresence({required String userId});

  /// Realtime `last_seen_at` of [userId] (null if never seen). Drives the
  /// online / "last seen …" line in the chat header.
  Stream<DateTime?> lastSeenOf({required String userId});
}

/// The order of a list of posts ([PostsBaseRepository.getPage]).
enum PostOrder {
  /// Newest first.
  newest,

  /// The home feed: posts by the people you follow and your own first, then
  /// everyone else's; each part newest first. A new account still sees posts.
  feed,

  /// Trends: the last 14 days first, then everything older; each part by
  /// score — likes plus twice the comments, plus one, divided by the age in
  /// days plus two, so a post fades as it ages.
  trending,
}

/// Abstract base class for a posts repository.
abstract class PostsBaseRepository {
  /// Reads the associated post from the database by the [id].
  Future<Post?> getPostBy({required String id});

  /// Fetches the profiles of users who liked post, found by [postId].
  Future<List<User>> getPostLikers({
    required String postId,
    int limit = 30,
    int offset = 0,
  });

  /// Fetches the profiles of users who liked the post, identified by [postId]
  /// and who are in followings of the user identified by current user `id`.
  Future<List<User>> getPostLikersInFollowings({
    required String postId,
    int limit = 3,
    int offset = 0,
  });

  /// Likes or unlikes the post (or, with `post: false`, the comment) [id].
  /// [liked] sets the outcome (a double tap only ever likes); null flips it.
  Future<void> like({
    required String id,
    bool post = true,
    bool? liked,
  });

  /// Returns a real-time stream of likes count of post by provided [id].
  Stream<int> likesOf({
    required String id,
    bool post = true,
  });

  /// The counts and the viewer's state for every post in [postIds], in one
  /// live query, keyed by post id. A post that isn't on this device is left
  /// out.
  Stream<Map<String, PostStats>> postStatsOf({required List<String> postIds});

  /// Likes and liked-by state for each of [commentIds], in one live query,
  /// keyed by comment id — see [CommentStats].
  Stream<Map<String, CommentStats>> commentStatsOf({
    required List<String> commentIds,
  });

  /// Returns a real-time stream of whether the post by [id] is liked by user
  /// identified by [userId].
  Stream<bool> isLiked({
    required String id,
    String? userId,
    bool post = true,
  });

  /// Toggles the saved (bookmarked) state of the post identified by [postId]
  /// for the currently authenticated user.
  Future<void> bookmarkPost({required String postId});

  /// Returns a real-time stream of whether the post identified by [postId] is
  /// saved (bookmarked) by the user identified by [userId].
  Stream<bool> isBookmarked({required String postId, String? userId});

  /// Returns the page of posts saved (bookmarked) by the currently
  /// authenticated user with provided [offset] and [limit].
  Future<List<Post>> getSavedPosts({
    required int offset,
    required int limit,
  });

  /// Toggles the archived state of the post identified by [postId] for the
  /// currently authenticated user.
  Future<void> archivePost({required String postId});

  /// Keeps the post identified by [postId] out of the current user's feed
  /// ("Don't show again"). Stored on this device only.
  Future<void> hidePost({required String postId});

  /// Returns a real-time stream of whether the post identified by [postId] is
  /// archived by the user identified by [userId].
  Stream<bool> isArchived({required String postId, String? userId});

  /// Returns the page of posts archived by the currently authenticated user
  /// with provided [offset] and [limit].
  Future<List<Post>> getArchivedPosts({
    required int offset,
    required int limit,
  });

  /// Returns the page of posts with provided [offset] and [limit], in
  /// [order].
  Future<List<Post>> getPage({
    required int offset,
    required int limit,
    bool onlyReels = false,
    PostOrder order = PostOrder.newest,
  });

  /// How many posts come before [postId] in [getPage]'s [order] (its offset
  /// there), or null when it isn't in that list (deleted, hidden, not
  /// visible).
  Future<int?> feedPositionOf({
    required String postId,
    PostOrder order = PostOrder.newest,
  });

  /// Create a new post with provided details.
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
  });

  /// Returns a real-time stream of the distinct ISO 3166-2 region codes the
  /// user identified by [userId] has posted from (their "visited" regions).
  Stream<Set<String>> visitedRegionsOf({required String userId});

  /// Returns a real-time stream mapping each ISO 3166-2 region code to the
  /// number of posts and story pins [userId] has placed there (plus regions
  /// marked visited without either) — used to shade each region on the
  /// travel map by density.
  Stream<Map<String, int>> visitedRegionCountsOf({required String userId});

  /// Returns a real-time stream of the exact `(lat, lng)` of every post by
  /// [userId] that has a picked location — one marker per post on the map.
  Stream<List<({double lat, double lng, String? name})>> visitedPointsOf({
    required String userId,
  });

  /// Returns a real-time stream of the `(lat, lng, name)` of every story by
  /// [userId] that is pinned to a place — one per pin, read from the pins
  /// themselves, so removing one removes its marker. Ignores `expires_at`, so
  /// a pin stays on the map even after the 24h story itself has expired.
  Stream<List<({double lat, double lng, String? name})>> storyPointsOf({
    required String userId,
  });

  /// Deletes the post with provided [id].
  /// Returns the optional `id` of the deleted post.
  Future<String?> deletePost({required String id});

  /// Updates the post with provided [id] and optional parameters to update.
  Future<Post?> updatePost({required String id, String? caption});

  /// Returns the stream of real-time posts of the current user.
  ///
  /// [limit] caps the reactive window (for scroll pagination); null = all posts.
  Stream<List<Post>> postsOf({String? userId, int? limit});

  /// Posts by [userId] placed in the ISO 3166-2 region [iso].
  Stream<List<Post>> postsInRegion({
    required String userId,
    required String iso,
  });

  /// Posts by [userId] placed within [radiusDegrees] of ([lat], [lng]).
  ///
  /// A radius rather than an exact match: each post's pin is dropped by hand,
  /// so two posts from the same spot never carry identical coordinates. Kept
  /// tight (~22 m) so distinct pins in one region don't bleed together, while
  /// hand-drops aimed at the same place still group.
  Stream<List<Post>> postsAtPoint({
    required String userId,
    required double lat,
    required double lng,
    double radiusDegrees = 0.0002,
  });

  /// Returns a stream of amount of posts of the user identified by [userId].
  Stream<int> postsAmountOf({required String userId});

  /// Returns a stream of amount of comments of the post identified by [postId].
  Stream<int> commentsAmountOf({required String postId});

  /// Returns a stream of comments of the post identified by [postId].
  Stream<List<Comment>> commentsOf({required String postId});

  /// Returns a stream of replied comments of the comment identified by
  /// [commentId].
  Stream<List<Comment>> repliedCommentsOf({required String commentId});

  /// Created a comment with provided details.
  Future<void> createComment({
    required String content,
    required String postId,
    required String userId,
    String? repliedToCommentId,
  });

  /// Delete the comment by associated [id].
  Future<void> deleteComment({required String id});
}

/// The abstract base class for a stories repository.
abstract class StoriesBaseRepository {
  /// {@macro stories_base_repository}
  const StoriesBaseRepository();

  /// Broadcasts the stream of the stories from the database.
  Stream<List<Story>> getStories({
    required String userId,
    bool includeAuthor = true,
  });

  /// Every active story the signed-in user may see, from everyone, oldest
  /// first — one live query that every story ring reads from (see
  /// `ActiveStories` in stories_repository). Without author profiles.
  Stream<List<Story>> activeStories();

  /// The single story identified by [id] (with its author), or `null` if it no
  /// longer exists. Not filtered by expiry, so a shared story still resolves.
  Future<Story?> getStoryBy({required String id});

  /// The user's expired stories — everything past its 24h window, newest
  /// first. Only ever shown to the author.
  Stream<List<Story>> archivedStoriesOf({required String userId});

  /// Stories the owner of [userId]'s map hand-pinned to one place.
  ///
  /// Nothing lands here on its own: unlike the location a story was shot at,
  /// these are chosen out of the archive. [lat]/[lng] narrow it to a single pin;
  /// leave them null for every story pinned anywhere in [regionIso].
  Stream<List<Story>> locationStoriesOf({
    required String userId,
    required String regionIso,
    double? lat,
    double? lng,
    double radiusDegrees = 0.0002,
  });

  /// Pins [storyId] to a place. Doing it twice is a no-op.
  Future<void> pinStoryToLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  });

  /// Pins [storyId] to a place (and marks it there on the map) and adds it to
  /// a highlight — the existing [highlightId] or a new one named
  /// [newHighlightName] — in one transaction: either all of it is saved or
  /// none. The pin sheet used to save step by step and could stop half-way.
  Future<void> pinStory({
    required String userId,
    required String storyId,
    required String regionIso,
    required double lat,
    required double lng,
    String? placeName,
    String? highlightId,
    String? newHighlightName,
    String? coverUrl,
  });

  /// The region saved with [userId]'s pin or post near ([lat], [lng]), or
  /// null when they have none there.
  Future<String?> savedRegionNear({
    required String userId,
    required double lat,
    required double lng,
  });

  /// Removes a pin made by [pinStoryToLocation].
  Future<void> unpinStoryFromLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  });

  /// Creates the [Story] with the provided data.
  Future<void> createStory({
    required User author,
    required StoryContentType contentType,
    required String contentUrl,
    String? id,
    int? duration,
    String? locationName,
    double? locationLat,
    double? locationLng,
  });

  /// Deletes the [Story] identified by [id].
  Future<void> deleteStory({required String id});

  /// Uploads the story media into the Supabase storage.
  Future<String> uploadStoryMedia({
    required String storyId,
    required File imageFile,
    required Uint8List imageBytes,
  });

  /// Records that [viewerId] has seen the story [storyId]. Idempotent — a
  /// second view by the same person changes nothing.
  Future<void> recordStoryView({
    required String storyId,
    required String viewerId,
  });

  /// Live count of distinct viewers of [storyId].
  Stream<int> storyViewsCountOf({required String storyId});

  /// The people who have viewed [storyId], most recent first. Only the story's
  /// author receives these rows (enforced by the sync rules).
  ///
  /// [limit] caps the reactive window for scroll pagination; null = all.
  Stream<List<User>> storyViewersOf({required String storyId, int? limit});

  /// Toggles a like by [userId] on the story [storyId].
  Future<void> likeStory({required String storyId, required String userId});

  /// Whether [userId] has liked [storyId].
  Stream<bool> isStoryLiked({required String storyId, required String userId});

  /// Live like count of [storyId].
  Stream<int> storyLikesCountOf({required String storyId});
}

/// {@template client}
/// Represents a client that interacts with various repositories.
///
/// ### Example usage:
/// ```dart
/// final powerSyncRepository = PowerSyncRepository();
/// final client = PowerSyncDatabaseClient(powerSyncRepository);
///
/// client.createPost(
///   id: 'post123',
///   userId: 'user123',
///   caption: 'Hello, world!',
///   media: 'https://example.com/image.jpg',
/// );
/// ```
/// {@endtemplate}
abstract class DatabaseClient
    implements UserBaseRepository, PostsBaseRepository, StoriesBaseRepository {
  /// {@macro database_client}
  const DatabaseClient();

  /// Permanently deletes the current account and every row it owns from the
  /// database. Identifies the caller from the signed-in JWT, so it takes no
  /// arguments. Irreversible.
  Future<void> deleteAccount();

  /// The ids of the current user's followings who CURRENTLY have a non-expired
  /// story. Reactive — re-emits when a story is posted or expires. Lets the
  /// stories tray subscribe only to authors who actually have a story instead
  /// of opening a live feed (and fetching a profile) for every followed user.
  Stream<List<String>> followingsWithActiveStories({String? userId});

  /// Fetches the profiles for [ids] in one query. Empty [ids] → empty list.
  Future<List<User>> profilesByIds(List<String> ids);
}

/// {@template power_sync_database_client}
/// A class representing a PowerSyncDatabaseClient.
///
/// It allows users to perform various operations such as creating posts,
/// retrieving posts, liking posts, following users, and more.
/// {@endtemplate}
class PowerSyncDatabaseClient extends DatabaseClient {
  /// {@macro power_sync_database_client}
  PowerSyncDatabaseClient({required PowerSyncRepository powerSyncRepository})
    : _powerSyncRepository = powerSyncRepository;

  final PowerSyncRepository _powerSyncRepository;

  @override
  String? get currentUserId => EntraSession.instance.current?.userId;

  // --- Privacy and blocking -------------------------------------------------
  //
  // Every list of other people's content or people goes through one of these
  // two rules, so a private account and a block hold everywhere, not only on
  // the profile page. All rows still sync to the phone (the server-side rule
  // is a separate fix); these keep them off the screen. Both directions of a
  // block sync (`blocked_users` rows where I'm the blocker or the blocked), so
  // "they blocked me" hides them as well. Live (`watch`) queries refresh on
  // their own when a block, follow or privacy row changes, since the rule's
  // tables are part of the query.

  /// The signed-in user's id as a SQL literal, or `NULL` when signed out.
  /// Inlined rather than bound so the rule fits queries that already use
  /// positional (`?` / `?1`) parameters. Only an id shaped like a UUID is
  /// ever inlined.
  String get _viewerSql {
    final id = currentUserId;
    if (id == null || !_uuidShape.hasMatch(id)) return 'NULL';
    return "'$id'";
  }

  static final _uuidShape = RegExp(r'^[0-9a-fA-F-]{36}$');

  /// SQL that is true when neither the signed-in user nor [userColumn] has
  /// blocked the other — for showing a person at all (search, suggestions,
  /// followers, likers, commenters, notifications).
  String _notBlockedSql(String userColumn) {
    final me = _viewerSql;
    return '''
NOT EXISTS (
  SELECT 1 FROM blocked_users vis_b
  WHERE (vis_b.blocker_id = $me AND vis_b.blocked_id = $userColumn)
     OR (vis_b.blocker_id = $userColumn AND vis_b.blocked_id = $me)
)''';
  }

  /// SQL that is true when content by [authorColumn] may be shown to the
  /// signed-in user: it is their own, or nobody blocked anybody and the author
  /// is public or followed by them (an accepted follow; legacy NULL status
  /// counts as accepted).
  String _visibleAuthorSql(String authorColumn) {
    final me = _viewerSql;
    return '''
($authorColumn = $me OR (
  ${_notBlockedSql(authorColumn)}
  AND (
    COALESCE((SELECT vis_p.is_private FROM profiles vis_p
              WHERE vis_p.id = $authorColumn), 0) = 0
    OR EXISTS (
      SELECT 1 FROM subscriptions vis_s
      WHERE vis_s.subscriber_id = $me
        AND vis_s.subscribed_to_id = $authorColumn
        AND COALESCE(vis_s.status, 'accepted') = 'accepted'
    )
  )
))''';
  }

  /// SQL that is true when [postsTable]'s media are all uploaded, or the post
  /// is the signed-in user's own. Older app versions created a post before its
  /// upload finished, with `file://` URLs that only work on the author's phone;
  /// everyone else would see broken images, so such a post stays hidden until
  /// the author's phone replaces them.
  String _postReadySql(String postsTable) =>
      "($postsTable.user_id = $_viewerSql "
      "OR $postsTable.media NOT LIKE '%file://%')";

  /// Everyone the signed-in user blocked or was blocked by — for filtering
  /// results that come from the server rather than the local database.
  Future<Set<String>> _blockedPeerIds() async {
    final me = currentUserId;
    if (me == null) return const {};
    final rows = await _powerSyncRepository.db().getAll(
      '''
SELECT blocked_id AS peer FROM blocked_users WHERE blocker_id = ?1
UNION
SELECT blocker_id FROM blocked_users WHERE blocked_id = ?1''',
      [me],
    );
    return {for (final row in rows) row['peer'] as String};
  }

  @override
  Stream<User> profile({required String id}) => _powerSyncRepository
      .db()
      .watch(
        // Private fields come from `my_profile`, which only the owner
        // receives. A value still in `profiles` wins: it is an edit made on
        // this device that hasn't synced back yet (once it has, the synced
        // `profiles` row no longer carries it).
        '''
SELECT
  p.id, p.full_name, p.username, p.avatar_url, p.referral_tier,
  p.referral_tier_expires_at, p.bio, p.is_private, p.telegram, p.website,
  p.instagram, p.onboarded_at, p.notifications_seen_at,
  COALESCE(p.email, mp.email) AS email,
  COALESCE(p.birthday, mp.birthday) AS birthday,
  COALESCE(p.gender, mp.gender) AS gender,
  COALESCE(p.push_token, mp.push_token) AS push_token,
  COALESCE(p.last_seen_at, mp.last_seen_at) AS last_seen_at
FROM profiles p
  LEFT JOIN my_profile mp ON mp.id = p.id
WHERE p.id = ?''',
        parameters: [id],
      )
      .map(
        (event) => event.isEmpty ? User.anonymous : User.fromJson(event.first),
      );

  @override
  Future<void> updatePresence({required String userId}) async {
    // UTC, like what syncs back (the server stamps its own now() anyway, see
    // track_presence): a local time without a zone read as UTC up there.
    await _powerSyncRepository.db().execute(
      'UPDATE profiles SET last_seen_at = ? WHERE id = ?',
      [DateTime.timestamp().toIso8601String(), userId],
    );
  }

  @override
  Stream<DateTime?> lastSeenOf({required String userId}) => _powerSyncRepository
      .db()
      .watch(
        'SELECT last_seen_at FROM profiles WHERE id = ?',
        parameters: [userId],
      )
      .map((event) {
        if (event.isEmpty) return null;
        final raw = event.first['last_seen_at'] as String?;
        if (raw == null || raw.isEmpty) return null;
        return DateTime.tryParse(raw);
      });

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
  }) async {
    if (currentUserId == null) return null;
    final result = await Future.wait([
      _powerSyncRepository.db().execute(
        '''
    INSERT INTO posts(id, user_id, caption, media, location, location_country, location_region, location_name, location_lat, location_lng, created_at)
    VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    RETURNING *
    ''',
        [
          id,
          currentUserId,
          caption,
          media,
          location,
          locationCountry,
          locationRegion,
          locationName,
          locationLat,
          locationLng,
          DateTime.timestamp().toIso8601String(),
        ],
      ),
      _powerSyncRepository.db().getOptional(
        '''
SELECT * FROM profiles WHERE id = ?
''',
        [currentUserId],
      ),
    ]);
    if (result.isEmpty) return null;
    final json = Map<String, dynamic>.from((result.first as ResultSet).first);
    final authorRow = result.last as Row?;
    final author = authorRow != null
        ? User.fromJson(authorRow)
        : User.anonymous;
    final postMedia = _decodeMedia(json['media'] as String);
    return Post.fromJson(json, media: postMedia).copyWith(author: author);
  }

  @override
  Stream<Set<String>> visitedRegionsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
    SELECT DISTINCT location_region FROM posts
    WHERE user_id = ?1 AND location_region IS NOT NULL AND location_region != ''
      AND ${_visibleAuthorSql('?1')}
    ''',
            parameters: [userId],
          )
          .map(
            (result) =>
                result.map((row) => row['location_region'] as String).toSet(),
          );

  @override
  Stream<Map<String, int>> visitedRegionCountsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
    SELECT region AS location_region, SUM(c) AS c FROM (
      SELECT location_region AS region, COUNT(*) AS c FROM posts
      WHERE user_id = ?1 AND location_region IS NOT NULL
        AND location_region != ''
      GROUP BY location_region
      UNION ALL
      -- Regions marked without a post still colour the map.
      SELECT region_iso AS region, 1 AS c FROM visited_regions
      WHERE user_id = ?1
      UNION ALL
      -- So does a story pinned to a place, by the region saved with the pin
      -- (the same pins storyPointsOf draws). The maps used to work this out
      -- from each pin's coordinates on every repaint.
      SELECT ls.region_iso AS region, COUNT(*) AS c FROM location_stories ls
        INNER JOIN stories s ON s.id = ls.story_id AND s.user_id = ls.user_id
      WHERE ls.user_id = ?1 AND ls.lat IS NOT NULL AND ls.lng IS NOT NULL
        AND ls.region_iso IS NOT NULL AND ls.region_iso != ''
      GROUP BY ls.region_iso
    )
    WHERE ${_visibleAuthorSql('?1')}
    GROUP BY region
    ''',
            parameters: [userId],
          )
          .map(
            (result) => <String, int>{
              for (final row in result)
                row['location_region'] as String: (row['c'] as num).toInt(),
            },
          );

  @override
  Stream<List<({double lat, double lng, String? name})>> visitedPointsOf({
    required String userId,
  }) => _powerSyncRepository
      .db()
      .watch(
        '''
    SELECT location_lat, location_lng, location_name FROM posts
    WHERE user_id = ?1 AND location_lat IS NOT NULL AND location_lng IS NOT NULL
      AND ${_visibleAuthorSql('?1')}
    ORDER BY created_at DESC
    ''',
        parameters: [userId],
      )
      .map(
        (result) => result
            .map(
              (row) => (
                lat: (row['location_lat'] as num).toDouble(),
                lng: (row['location_lng'] as num).toDouble(),
                name: row['location_name'] as String?,
              ),
            )
            .toList(),
      );

  @override
  Stream<List<({double lat, double lng, String? name})>> storyPointsOf({
    required String userId,
  }) => _powerSyncRepository
      .db()
      .watch(
        // From the pins, not the story's own coordinates: unpinning left
        // those behind, so the marker stayed and opened an empty place.
        '''
    SELECT ls.lat AS location_lat, ls.lng AS location_lng, s.location_name
    FROM location_stories ls
      INNER JOIN stories s ON s.id = ls.story_id AND s.user_id = ls.user_id
    WHERE ls.user_id = ?1 AND ls.lat IS NOT NULL AND ls.lng IS NOT NULL
      AND ${_visibleAuthorSql('?1')}
    ''',
        parameters: [userId],
      )
      .map(
        (result) => result
            .map(
              (row) => (
                lat: (row['location_lat'] as num).toDouble(),
                lng: (row['location_lng'] as num).toDouble(),
                name: row['location_name'] as String?,
              ),
            )
            .toList(),
      );

  @override
  Stream<int> postsAmountOf({required String userId}) => _powerSyncRepository
      .db()
      .watch(
        '''
    SELECT COUNT(*) as posts_count FROM posts where user_id = ?
    ''',
        parameters: [userId],
      )
      .map(
        (event) =>
            event.safeMap((element) => element['posts_count']).first as int,
      );

  @override
  Stream<int> referralCountOf({required String userId}) => _powerSyncRepository
      .db()
      .watch(
        'SELECT COUNT(*) AS referral_count FROM referrals '
        'WHERE referrer_id = ?',
        parameters: [userId],
      )
      .map(
        (event) =>
            event.safeMap((element) => element['referral_count']).first as int,
      );

  @override
  Stream<int> referralTierOf({required String userId}) =>
      travelTierOf(userId: userId);

  /// The badge everyone sees, read off the globally-synced profile.
  ///
  /// It cannot be computed from `referrals`: that table only syncs to the
  /// person who owns those invites, so a device has no rows for anyone else and
  /// every other profile would come out bare. The server publishes the earned
  /// tier and its end date here; the expiry is re-checked on the device so a
  /// badge visibly lapses on time even if the server has not run since.
  @override
  Stream<int> travelTierOf({required String userId}) => _powerSyncRepository
      .db()
      .watch(
        'SELECT referral_tier, referral_tier_expires_at FROM profiles '
        'WHERE id = ?',
        parameters: [userId],
      )
      .map((event) {
        final rows = event.toList();
        if (rows.isEmpty) return 0;
        final row = rows.first;
        final tier = (row['referral_tier'] as int?) ?? 0;
        if (tier <= 0) return 0;
        final endsAt = DateTime.tryParse(
          (row['referral_tier_expires_at'] as String?) ?? '',
        );
        if (endsAt == null) return 0;
        return DateTime.now().isBefore(endsAt) ? tier : 0;
      });

  @override
  Stream<InviteBadgeStatus> inviteBadgeStatusOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT
  (SELECT COUNT(*) FROM posts
     WHERE user_id = ?1 AND location_lat IS NOT NULL) AS locations,
  (SELECT COUNT(DISTINCT location_region) FROM posts
     WHERE user_id = ?1 AND location_region IS NOT NULL
       AND location_region != '') AS regions,
  (SELECT group_concat(created_at) FROM (
     SELECT created_at FROM referrals
       WHERE referrer_id = ?1 ORDER BY created_at ASC
   )) AS invite_dates
''',
            parameters: [userId],
          )
          .map((event) {
            final rows = event.toList();
            if (rows.isEmpty) return InviteBadgeStatus.empty;
            final row = rows.first;

            final dates = <DateTime>[];
            for (final part in ((row['invite_dates'] as String?) ?? '').split(
              ',',
            )) {
              final at = DateTime.tryParse(part.trim());
              if (at != null) dates.add(at);
            }
            dates.sort();

            final locations = (row['locations'] as int?) ?? 0;
            final regions = (row['regions'] as int?) ?? 0;

            return InviteBadgeStatus(
              invites: dates.length,
              locations: locations,
              regions: regions,
              colorTier: inviteBadgeColorTier(
                locations: locations,
                regions: regions,
              ),
              expiresAt: premiumEndFromInvites(dates),
            );
          });

  @override
  Stream<Set<String>> markedRegionsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            'SELECT region_iso FROM visited_regions WHERE user_id = ?',
            parameters: [userId],
          )
          .map(
            (event) => event.map((row) => row['region_iso'] as String).toSet(),
          );

  @override
  Stream<List<StoryHighlight>> storyHighlightsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT h.id, h.user_id, h.name, h.cover_url,
       -- A highlight only holds its OWNER's stories. Count only those, so a
       -- highlight left with just another user's story (bad legacy data from
       -- before pinning was owner-gated) reads as empty and is hidden.
       (SELECT COUNT(*) FROM story_highlight_items i
          JOIN stories s ON s.id = i.story_id
          WHERE i.highlight_id = h.id AND s.user_id = h.user_id) AS story_count
FROM story_highlights h
WHERE h.user_id = ?1 AND ${_visibleAuthorSql('?1')}
-- Newest activity first: a highlight jumps to the front when a story is added
-- to it, not only when it is created.
ORDER BY COALESCE(
    (SELECT MAX(i.created_at) FROM story_highlight_items i
       WHERE i.highlight_id = h.id),
    h.created_at
  ) DESC
''',
            parameters: [userId],
          )
          .map(
            (event) =>
                event.safeMap(StoryHighlight.fromRow).toList(growable: false),
          );

  @override
  Stream<List<Story>> highlightStoriesOf({required String highlightId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT s.*, p.id as user_id, p.username, p.full_name, p.avatar_url
FROM story_highlight_items i
JOIN stories s ON s.id = i.story_id
JOIN story_highlights h ON h.id = i.highlight_id
LEFT JOIN profiles p ON p.id = s.user_id
-- Play only the highlight owner's own stories; ignore any foreign story that
-- was pinned in before pinning became owner-only.
WHERE i.highlight_id = ? AND s.user_id = h.user_id
  AND ${_visibleAuthorSql('s.user_id')}
ORDER BY i.created_at ASC
''',
            parameters: [highlightId],
          )
          .map(
            (event) => event.safeMap(Story.fromJson).toList(growable: false),
          );

  @override
  Future<void> createStoryHighlight({
    required String userId,
    required String name,
    required List<String> storyIds,
    String? coverUrl,
  }) async {
    final highlightId = uuid.v4();
    final now = DateTime.timestamp().toIso8601String();
    await _powerSyncRepository.db().writeTransaction((tx) async {
      await tx.execute(
        'INSERT INTO story_highlights(id, user_id, name, cover_url, created_at) '
        'VALUES (?, ?, ?, ?, ?)',
        [highlightId, userId, name, coverUrl, now],
      );
      for (final storyId in storyIds) {
        await tx.execute(
          'INSERT INTO story_highlight_items(id, highlight_id, story_id, created_at) '
          'VALUES (?, ?, ?, ?)',
          [uuid.v4(), highlightId, storyId, now],
        );
      }
    });
  }

  @override
  Future<void> deleteStoryHighlight({required String highlightId}) async {
    await _powerSyncRepository.db().writeTransaction((tx) async {
      await tx.execute(
        'DELETE FROM story_highlight_items WHERE highlight_id = ?',
        [highlightId],
      );
      await tx.execute(
        'DELETE FROM story_highlights WHERE id = ?',
        [highlightId],
      );
    });
  }

  @override
  Future<void> addStoryToHighlight({
    required String highlightId,
    required String storyId,
  }) async {
    // SELECT-then-INSERT, same as pinStoryToLocation: the local PowerSync
    // tables carry no unique index for ON CONFLICT to resolve against.
    final existing = await _powerSyncRepository.db().getAll(
      'SELECT id FROM story_highlight_items '
      'WHERE highlight_id = ? AND story_id = ?',
      [highlightId, storyId],
    );
    if (existing.isNotEmpty) return;
    await _powerSyncRepository.db().execute(
      'INSERT INTO story_highlight_items(id, highlight_id, story_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [uuid.v4(), highlightId, storyId, DateTime.timestamp().toIso8601String()],
    );
  }

  @override
  Future<void> setStoryLocation({
    required String storyId,
    required double lat,
    required double lng,
    String? name,
  }) {
    // Persist the pin's name so the travel map can label it. This used to write
    // only lat/lng, to keep the story-view "place chip" from appearing — but
    // that chip is deliberately not rendered (see StoriesAuthorListTile), so the
    // name now only surfaces on the map, which is what we want. A null/blank
    // name leaves any existing label untouched (no clobber).
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return _powerSyncRepository.db().execute(
        'UPDATE stories SET location_lat = ?, location_lng = ?, location_name = ? '
        'WHERE id = ?',
        [lat, lng, trimmed, storyId],
      );
    }
    return _powerSyncRepository.db().execute(
      'UPDATE stories SET location_lat = ?, location_lng = ? WHERE id = ?',
      [lat, lng, storyId],
    );
  }

  @override
  Future<bool> isStoryPinned({required String storyId}) async {
    final loc = await _powerSyncRepository.db().getAll(
      'SELECT 1 FROM location_stories WHERE story_id = ? LIMIT 1',
      [storyId],
    );
    if (loc.isNotEmpty) return true;
    final hl = await _powerSyncRepository.db().getAll(
      'SELECT 1 FROM story_highlight_items WHERE story_id = ? LIMIT 1',
      [storyId],
    );
    return hl.isNotEmpty;
  }

  @override
  Future<void> unpinStoryEverywhere({required String storyId}) =>
      _powerSyncRepository.db().writeTransaction((tx) async {
        await tx.execute(
          'DELETE FROM location_stories WHERE story_id = ?',
          [storyId],
        );
        await tx.execute(
          'DELETE FROM story_highlight_items WHERE story_id = ?',
          [storyId],
        );
        await tx.execute(
          'UPDATE stories SET location_lat = NULL, location_lng = NULL '
          'WHERE id = ?',
          [storyId],
        );
      });

  @override
  Stream<List<User>> savedProfilesOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT p.* FROM saved_profiles s
JOIN profiles p ON p.id = s.profile_id
WHERE s.saver_id = ? AND ${_notBlockedSql('p.id')}
ORDER BY s.created_at DESC
''',
            parameters: [userId],
          )
          .map(
            (event) => event.safeMap(User.fromJson).toList(growable: false),
          );

  @override
  Stream<bool> isProfileSaved({
    required String userId,
    required String profileId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT 1 FROM saved_profiles '
        'WHERE saver_id = ? AND profile_id = ? LIMIT 1',
        parameters: [userId, profileId],
      )
      .map((event) => event.isNotEmpty);

  @override
  Future<void> saveProfile({
    required String userId,
    required String profileId,
  }) async {
    final db = _powerSyncRepository.db();
    // De-dupe by hand: PowerSync's local tables carry no unique index, so an
    // `ON CONFLICT(saver_id, profile_id)` clause has nothing to match and the
    // insert fails outright.
    final existing = await db.getAll(
      'SELECT id FROM saved_profiles WHERE saver_id = ? AND profile_id = ? '
      'LIMIT 1',
      [userId, profileId],
    );
    if (existing.isNotEmpty) return;
    await db.execute(
      'INSERT INTO saved_profiles(id, saver_id, profile_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [uuid.v4(), userId, profileId, DateTime.timestamp().toIso8601String()],
    );
  }

  @override
  Future<void> unsaveProfile({
    required String userId,
    required String profileId,
  }) => _powerSyncRepository.db().execute(
    'DELETE FROM saved_profiles WHERE saver_id = ? AND profile_id = ?',
    [userId, profileId],
  );

  @override
  Future<void> setVisitedRegions({
    required String userId,
    required Set<String> regionIsos,
  }) async {
    final db = _powerSyncRepository.db();
    await db.writeTransaction((tx) async {
      await tx.execute(
        'DELETE FROM visited_regions WHERE user_id = ?',
        [userId],
      );
      for (final iso in regionIsos) {
        await tx.execute(
          'INSERT INTO visited_regions(id, user_id, region_iso, created_at) '
          'VALUES (?, ?, ?, ?)',
          [uuid.v4(), userId, iso, DateTime.timestamp().toIso8601String()],
        );
      }
    });
  }

  @override
  Future<String> redeemReferral({required String handle}) async {
    final result = await _powerSyncRepository.postgrest().rpc<dynamic>(
      'redeem_referral',
      params: {'p_handle': handle},
    );
    return result is String ? result : 'unknown';
  }

  @override
  Future<void> deleteAccount() async {
    // A single server-side function does the whole cascade under one identity
    // (the JWT `sub`), so a half-deleted account can never be left behind.
    await _powerSyncRepository.postgrest().rpc<dynamic>('delete_account');
  }

  @override
  Stream<List<NotificationItem>> notificationsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT act.type AS type, act.actor_id AS actor_id, act.post_id AS post_id,
       act.content AS content, act.created_at AS created_at,
       act.post_thumb AS post_thumb,
       pr.username AS actor_username, pr.avatar_url AS actor_avatar,
       pr.full_name AS actor_name
FROM (
  SELECT 'like' AS type, l.user_id AS actor_id, l.post_id AS post_id,
         NULL AS content, l.created_at AS created_at,
         CASE WHEN json_valid(p.media) THEN
           CASE json_extract(p.media, '\$[0].type')
             WHEN '__video_media__' THEN json_extract(p.media, '\$[0].first_frame_url')
             ELSE coalesce(json_extract(p.media, '\$[0].thumb_url'),
                           json_extract(p.media, '\$[0].url'))
           END
         END AS post_thumb
  FROM likes l
  JOIN posts p ON p.id = l.post_id
  WHERE p.user_id = ?1 AND l.user_id != ?1 AND l.post_id IS NOT NULL
  UNION ALL
  SELECT 'comment', c.user_id, c.post_id, c.content, c.created_at,
         CASE WHEN json_valid(p.media) THEN
           CASE json_extract(p.media, '\$[0].type')
             WHEN '__video_media__' THEN json_extract(p.media, '\$[0].first_frame_url')
             ELSE coalesce(json_extract(p.media, '\$[0].thumb_url'),
                           json_extract(p.media, '\$[0].url'))
           END
         END
  FROM comments c
  JOIN posts p ON p.id = c.post_id
  WHERE p.user_id = ?1 AND c.user_id != ?1
  UNION ALL
  -- A pending row is a follow REQUEST (Accept/Decline); an accepted row is a
  -- plain "started following you" notice.
  SELECT (CASE WHEN s.status = 'pending' THEN 'follow_request' ELSE 'follow' END),
         s.subscriber_id, NULL, NULL, s.created_at, NULL
  FROM subscriptions s
  WHERE s.subscribed_to_id = ?1 AND s.subscriber_id != ?1
) act
LEFT JOIN profiles pr ON pr.id = act.actor_id
WHERE ${_notBlockedSql('act.actor_id')}
ORDER BY act.created_at DESC
LIMIT 80
''',
            parameters: [userId],
          )
          .map(
            (result) => result
                .map(
                  (row) => NotificationItem(
                    type: NotificationItem.typeFromString(
                      row['type'] as String,
                    ),
                    actorId: (row['actor_id'] as String?) ?? '',
                    actorUsername:
                        (row['actor_username'] as String?) ?? 'Someone',
                    actorAvatarUrl: row['actor_avatar'] as String?,
                    actorFullName: row['actor_name'] as String?,
                    postId: row['post_id'] as String?,
                    postThumbUrl: row['post_thumb'] as String?,
                    content: row['content'] as String?,
                    createdAt: DateTime.tryParse(
                      (row['created_at'] as String?) ?? '',
                    ),
                  ),
                )
                .toList(),
          );

  @override
  Stream<int> unreadNotificationsCount({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT COUNT(*) AS c
FROM (
  SELECT l.user_id AS actor_id, l.created_at AS created_at
  FROM likes l
  JOIN posts p ON p.id = l.post_id
  WHERE p.user_id = ?1 AND l.user_id != ?1 AND l.post_id IS NOT NULL
  UNION ALL
  SELECT c.user_id, c.created_at
  FROM comments c
  JOIN posts p ON p.id = c.post_id
  WHERE p.user_id = ?1 AND c.user_id != ?1
  UNION ALL
  SELECT s.subscriber_id, s.created_at
  FROM subscriptions s
  WHERE s.subscribed_to_id = ?1 AND s.subscriber_id != ?1
) act
-- The watermark lives on the profile, so this join puts `profiles` in the
-- watched set too and the badge clears itself the moment it is bumped.
LEFT JOIN profiles me ON me.id = ?1
WHERE (me.notifications_seen_at IS NULL
       OR act.created_at > me.notifications_seen_at)
  AND ${_notBlockedSql('act.actor_id')}
''',
            parameters: [userId],
          )
          .map((rows) => (rows.first['c'] as int?) ?? 0);

  @override
  Future<void> markNotificationsSeen({required String userId}) =>
      _powerSyncRepository.db().execute(
        'UPDATE profiles SET notifications_seen_at = ?2 WHERE id = ?1',
        [userId, DateTime.now().toUtc().toIso8601String()],
      );

  /// Shared shape of the location-filtered post queries: same select and
  /// hydration as [postsOf], only the WHERE clause differs.
  Stream<List<Post>> _postsWhere(String where, List<Object?> parameters) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT
  posts.*,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  posts
  left join profiles p on posts.user_id = p.id
WHERE ($where) AND ${_visibleAuthorSql('posts.user_id')}
  AND ${_postReadySql('posts')}
ORDER BY created_at DESC
      ''',
            parameters: parameters,
          )
          .asyncMap(_hydratePosts);

  @override
  Stream<List<Post>> postsInRegion({
    required String userId,
    required String iso,
  }) => _postsWhere('posts.user_id = ? AND posts.location_region = ?', [
    userId,
    iso,
  ]);

  @override
  Stream<List<Post>> postsAtPoint({
    required String userId,
    required double lat,
    required double lng,
    double radiusDegrees = 0.0002,
  }) => _postsWhere(
    '''
posts.user_id = ?
  AND posts.location_lat IS NOT NULL
  AND posts.location_lng IS NOT NULL
  AND ABS(posts.location_lat - ?) <= ?
  AND ABS(posts.location_lng - ?) <= ?''',
    [userId, lat, radiusDegrees, lng, radiusDegrees],
  );

  /// Turns raw post rows into [Post]s, decoding their media off the UI isolate.
  Future<List<Post>> _hydratePosts(ResultSet result) async {
    final jsonListMedia = result
        .map((row) => Map<String, dynamic>.from(row)['media'] as String)
        .toList();
    final media = await _decodeMediaLists(jsonListMedia);
    final posts = <Post>[];
    for (var i = 0; i < result.length; i++) {
      final json = Map<String, dynamic>.from(result[i]);
      posts.add(
        Post.fromJson(
          json,
          media: List<Media>.from(media[i].map(Media.fromJson).toList()),
        ),
      );
    }
    return posts;
  }

  @override
  Stream<List<Post>> postsOf({String? userId, int? limit}) {
    if (currentUserId == null) return const Stream.empty();
    assert(
      userId != null && currentUserId != null,
      'Both given `userId` and `currentUserId` cannot be null',
    );
    // `limit` caps the reactive window so a prolific profile doesn't load and
    // decode its entire post history at once. Null keeps the old unbounded
    // behaviour for callers that don't paginate. The watch stays live — growing
    // the limit re-subscribes with a larger window.
    return _powerSyncRepository
        .db()
        .watch(
          '''
SELECT
  posts.*,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  posts
  left join profiles p on posts.user_id = p.id
WHERE user_id = ? AND ${_visibleAuthorSql('posts.user_id')}
  AND ${_postReadySql('posts')}
ORDER BY created_at DESC
${limit != null ? 'LIMIT ?' : ''}
      ''',
          parameters: [
            userId ?? currentUserId,
            if (limit != null) limit,
          ],
        )
        .asyncMap(
          (result) async {
            final jsonListMedia = result.map((row) {
              final json = Map<String, dynamic>.from(row);
              return json['media'] as String;
            }).toList();

            final media = await _decodeMediaLists(jsonListMedia);

            final posts = <Post>[];
            for (var i = 0; i < result.length; i++) {
              final json = Map<String, dynamic>.from(result[i]);
              final post = Post.fromJson(
                json,
                media: List<Media>.from(media[i].map(Media.fromJson).toList()),
              );
              posts.add(post);
            }
            return posts;
          },
        );
  }

  @override
  Future<String?> deletePost({required String id}) async {
    final result = await _powerSyncRepository.db().execute(
      'DELETE FROM posts WHERE id = ? RETURNING id',
      [id],
    );
    if (result.isEmpty) return null;
    return result.first['id'] as String;
  }

  /// A page's media JSON, decoded here when small (a page of posts is a few
  /// KB) and on a background isolate only for a big batch. Every page used
  /// to start an isolate — and set up platform channels in it it never used
  /// — which cost more than the decoding, on each refresh of a profile or
  /// place page.
  static Future<List<List<Map<String, dynamic>>>> _decodeMediaLists(
    List<String?> jsons,
  ) async {
    final size = jsons.fold<int>(0, (sum, json) => sum + (json?.length ?? 0));
    if (size < _isolateDecodeBytes) return _decodeMediaListsNow(jsons);
    return compute(_decodeMediaListsNow, jsons);
  }

  static const int _isolateDecodeBytes = 50 * 1024;

  static List<List<Map<String, dynamic>>> _decodeMediaListsNow(
    List<String?> jsons,
  ) => [
    for (final json in jsons)
      json == null
          ? <Map<String, dynamic>>[]
          : (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>(),
  ];

  /// One post's media JSON (a few hundred bytes), decoded in place. It used
  /// to start a background isolate per post — far more work than the decoding
  /// — e.g. for every post shared into a chat.
  static List<Media> _decodeMedia(String jsonMedia) => [
    for (final item in jsonDecode(jsonMedia) as List<dynamic>)
      Media.fromJson(item as Map<String, dynamic>),
  ];

  @override
  Future<int?> feedPositionOf({
    required String postId,
    PostOrder order = PostOrder.newest,
  }) async {
    // Same filters and order as getPage, so the row number is that post's
    // offset there.
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT position FROM (
  SELECT posts.id AS id,
         ROW_NUMBER() OVER (ORDER BY ${_postOrderSql(order)}) - 1 AS position
  FROM posts
  WHERE ${_visibleAuthorSql('posts.user_id')}
    AND ${_postReadySql('posts')}
    AND posts.id NOT IN (
      SELECT post_id FROM hidden_posts WHERE user_id = $_viewerSql
    )
)
WHERE id = ?1
    ''',
      [postId],
    );
    if (result.isEmpty) return null;
    return result.first['position'] as int?;
  }

  /// [PostOrder] as an ORDER BY list over `posts`. The id last, so posts
  /// that tie keep the same order from page to page.
  String _postOrderSql(PostOrder order) {
    final me = _viewerSql;
    return switch (order) {
      PostOrder.newest => 'posts.created_at DESC, posts.id',
      PostOrder.feed =>
        '''
CASE WHEN posts.user_id = $me OR EXISTS (
  SELECT 1 FROM subscriptions f
   WHERE f.subscriber_id = $me AND f.subscribed_to_id = posts.user_id
     AND (f.status = 'accepted' OR f.status IS NULL)
) THEN 0 ELSE 1 END,
posts.created_at DESC, posts.id''',
      // The first 19 characters are the UTC date and time in every format
      // the column has held; julianday() reads them whatever follows.
      PostOrder.trending =>
        '''
CASE WHEN julianday(substr(posts.created_at, 1, 19)) >= julianday('now') - 14
  THEN 0 ELSE 1 END,
((SELECT COUNT(*) FROM likes l WHERE l.post_id = posts.id)
  + 2 * (SELECT COUNT(*) FROM comments c
          WHERE c.post_id = posts.id AND ${_notBlockedSql('c.user_id')})
  + 1) * 1.0
  / (julianday('now') - julianday(substr(posts.created_at, 1, 19)) + 2) DESC,
posts.created_at DESC, posts.id''',
    };
  }

  @override
  Future<List<Post>> getPage({
    required int offset,
    required int limit,
    bool onlyReels = false,
    PostOrder order = PostOrder.newest,
  }) async {
    //     if (onlyReels) {
    //       final result = await _powerSyncRepository.db().execute(
    //         '''
    // SELECT
    //   posts.*,
    //   p.id as user_id,
    //   p.avatar_url as avatar_url,
    //   p.username as username
    // FROM
    //   posts
    //   inner join profiles p on posts.user_id = p.id
    // WHERE array_length(array(posts.media), 1) = 1
    //   AND posts.media.type = '__video_media__'
    // LIMIT ?1 OFFSET ?2
    //     ''',
    //         [limit, offset],
    //       );

    //       final posts = <Post>[];

    //       for (final row in result) {
    //         final json = Map<String, dynamic>.from(row);
    //         final post = Post.fromJson(json);
    //         posts.add(post);
    //       }
    //       return posts;
    //     }
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT
  posts.id,
  posts.created_at,
  posts.caption,
  posts.media,
  posts.updated_at,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  posts
  left join profiles p on posts.user_id = p.id
WHERE ${_visibleAuthorSql('posts.user_id')}
  AND ${_postReadySql('posts')}
  -- "Don't show again" (device-only, see the hidden_posts table).
  AND posts.id NOT IN (
    SELECT post_id FROM hidden_posts WHERE user_id = $_viewerSql
  )
ORDER BY ${_postOrderSql(order)} LIMIT ?1 OFFSET ?2
    ''',
      [limit, offset],
    );
    final jsonListMedia = result.map((row) {
      final json = Map<String, dynamic>.from(row);
      return json['media'] as String;
    }).toList();

    final media = await _decodeMediaLists(jsonListMedia);

    final posts = <Post>[];
    for (var i = 0; i < result.length; i++) {
      final json = Map<String, dynamic>.from(result[i]);
      final post = Post.fromJson(
        json,
        media: List<Media>.from(media[i].map(Media.fromJson).toList()),
      );
      posts.add(post);
    }
    return posts;
    // final result = await _powerSyncRepository.db().execute(
    //           '''
    // SELECT
    //   posts.*,
    //   p.id as user_id,
    //   p.avatar_url as avatar_url,
    //   p.username as username,
    //   p.full_name as full_name
    // FROM
    //   posts
    //   inner join profiles p on posts.user_id = p.id
    // ORDER BY created_at DESC LIMIT ?1 OFFSET ?2
    //     ''',
    //           [limit, offset],
    //         );

    //     final instaBlocks = result.map((row) {
    //       final json = Map<String, dynamic>.from(row);
    //       return Post.fromJson(json);
    //     }).toList();
    // return result;
  }

  @override
  Future<Post?> updatePost({required String id, String? caption}) async {
    final row = await _powerSyncRepository.db().execute(
      '''
UPDATE posts
SET
  caption = ?2,
  updated_at = ?3
WHERE id = ?1
RETURNING *
''',
      [id, caption, DateTime.timestamp().toIso8601String()],
    );
    if (row.isEmpty) return null;
    final json = Map<String, dynamic>.from(row.first);
    final media = _decodeMedia(json['media'] as String);
    return Post.fromJson(json, media: media);
  }

  @override
  Stream<int> likesOf({required String id, bool post = true}) {
    final statement = post ? 'post_id' : 'comment_id';
    return _powerSyncRepository
        .db()
        .watch(
          '''
SELECT COUNT(*) AS total_likes
FROM likes
WHERE $statement = ? AND $statement IS NOT NULL
''',
          parameters: [id],
        )
        .map(
          (result) => result.safeMap((row) => row['total_likes']).first as int,
        );
  }

  /// One row per comment: what its own three queries used to read
  /// ([likesOf] and [isLiked] for the viewer and for the post's author).
  @override
  Stream<Map<String, CommentStats>> commentStatsOf({
    required List<String> commentIds,
  }) {
    if (commentIds.isEmpty) return Stream.value(const {});
    return _powerSyncRepository
        .db()
        .watch(
          '''
SELECT
  c.id AS comment_id,
  (SELECT COUNT(*) FROM likes l WHERE l.comment_id = c.id) AS likes,
  EXISTS (SELECT 1 FROM likes l
     WHERE l.user_id = ?2 AND l.comment_id = c.id) AS is_liked,
  EXISTS (SELECT 1 FROM likes l
     JOIN posts p ON p.id = c.post_id
     WHERE l.user_id = p.user_id AND l.comment_id = c.id) AS is_liked_by_author
FROM comments c
WHERE c.id IN (SELECT value FROM json_each(?1))
''',
          parameters: [jsonEncode(commentIds), currentUserId],
        )
        .map(
          (rows) => {
            for (final row in rows)
              row['comment_id'] as String: CommentStats(
                likes: (row['likes'] as int?) ?? 0,
                isLiked: ((row['is_liked'] as int?) ?? 0) == 1,
                isLikedByPostAuthor:
                    ((row['is_liked_by_author'] as int?) ?? 0) == 1,
              ),
          },
        );
  }

  /// One row per post, each column what a card's own query used to read:
  /// [likesOf], [commentsAmountOf], [isLiked], [isBookmarked],
  /// `followingStatus`, [travelTierOf] and the length of [visitedPointsOf].
  /// PowerSync re-runs it when any of those tables changes — once for the
  /// whole screen instead of once per card and column.
  @override
  Stream<Map<String, PostStats>> postStatsOf({
    required List<String> postIds,
  }) {
    if (postIds.isEmpty) return Stream.value(const {});
    return _powerSyncRepository
        .db()
        .watch(
          '''
SELECT
  p.id AS post_id,
  (SELECT COUNT(*) FROM likes l
     WHERE l.post_id = p.id) AS likes,
  (SELECT COUNT(*) FROM comments c
     WHERE c.post_id = p.id AND ${_notBlockedSql('c.user_id')}) AS comments,
  EXISTS (SELECT 1 FROM likes l
     WHERE l.user_id = ?2 AND l.post_id = p.id) AS is_liked,
  EXISTS (SELECT 1 FROM saved_posts s
     WHERE s.user_id = ?2 AND s.post_id = p.id) AS is_bookmarked,
  EXISTS (SELECT 1 FROM subscriptions f
     WHERE f.subscriber_id = ?2 AND f.subscribed_to_id = p.user_id
       AND (f.status = 'accepted' OR f.status IS NULL)) AS is_followed,
  EXISTS (SELECT 1 FROM subscriptions f
     WHERE f.subscriber_id = ?2 AND f.subscribed_to_id = p.user_id
       AND f.status = 'pending') AS is_follow_requested,
  a.referral_tier AS author_tier,
  a.referral_tier_expires_at AS author_tier_expires_at,
  CASE WHEN ${_visibleAuthorSql('p.user_id')} THEN
    (SELECT COUNT(*) FROM posts v
       WHERE v.user_id = p.user_id
         AND v.location_lat IS NOT NULL AND v.location_lng IS NOT NULL)
  ELSE 0 END AS author_places
FROM posts p
LEFT JOIN profiles a ON a.id = p.user_id
WHERE p.id IN (SELECT value FROM json_each(?1))
''',
          parameters: [jsonEncode(postIds), currentUserId],
        )
        .map((rows) {
          final now = DateTime.now();
          return {
            for (final row in rows)
              row['post_id'] as String: PostStats(
                likes: (row['likes'] as int?) ?? 0,
                comments: (row['comments'] as int?) ?? 0,
                isLiked: (row['is_liked'] as int?) == 1,
                isBookmarked: (row['is_bookmarked'] as int?) == 1,
                isAuthorFollowed: (row['is_followed'] as int?) == 1,
                isAuthorFollowRequested:
                    (row['is_follow_requested'] as int?) == 1,
                authorTier: _liveTier(
                  row['author_tier'] as int?,
                  row['author_tier_expires_at'] as String?,
                  now,
                ),
                authorPlaces: (row['author_places'] as int?) ?? 0,
              ),
          };
        });
  }

  /// [travelTierOf]'s rule: a tier counts only until it runs out.
  static int _liveTier(int? tier, String? expiresAt, DateTime now) {
    if (tier == null || tier <= 0) return 0;
    final endsAt = DateTime.tryParse(expiresAt ?? '');
    if (endsAt == null) return 0;
    return now.isBefore(endsAt) ? tier : 0;
  }

  @override
  Stream<bool> isLiked({
    required String id,
    String? userId,
    bool post = true,
  }) {
    final statement = post ? 'post_id' : 'comment_id';
    return _powerSyncRepository
        .db()
        .watch(
          '''
      SELECT EXISTS (
        SELECT 1 
        FROM likes
        WHERE user_id = ? AND $statement = ? AND $statement IS NOT NULL
      )
''',
          parameters: [userId ?? currentUserId, id],
        )
        .map((event) => (event.first.values.first! as int).isTrue);
  }

  @override
  Future<Post?> getPostBy({required String id}) async {
    final row = await _powerSyncRepository.db().getOptional(
      '''
SELECT
  posts.*,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  posts
  join profiles p on posts.user_id = p.id 
WHERE posts.id = ? AND ${_visibleAuthorSql('posts.user_id')}
  AND ${_postReadySql('posts')}
  ''',
      [id],
    );
    if (row == null) return null;
    final json = Map<String, dynamic>.from(row);
    final postMedia = _decodeMedia(json['media'] as String);
    return Post.fromJson(json, media: postMedia);
  }

  @override
  Future<void> like({
    required String id,
    bool post = true,
    bool? liked,
  }) async {
    final me = currentUserId;
    if (me == null) return;
    final statement = post ? 'post_id' : 'comment_id';
    // Check and write in one transaction: writes run one at a time, so two
    // quick taps no longer both saw "not liked" and inserted twice (or a
    // stale "liked" turned a double tap into an unlike).
    await _powerSyncRepository.db().writeTransaction((tx) async {
      final exists = await tx.getOptional(
        'SELECT 1 FROM likes '
        'WHERE user_id = ? AND $statement = ? AND $statement IS NOT NULL',
        [me, id],
      );
      final want = liked ?? exists == null;
      if (want && exists == null) {
        await tx.execute(
          'INSERT INTO likes(user_id, $statement, id) VALUES(?, ?, uuid())',
          [me, id],
        );
      } else if (!want && exists != null) {
        await tx.execute(
          'DELETE FROM likes '
          'WHERE user_id = ? AND $statement = ? AND $statement IS NOT NULL',
          [me, id],
        );
      }
    });
  }

  @override
  Future<void> hidePost({required String postId}) async {
    final me = currentUserId;
    if (me == null) return;
    await _powerSyncRepository.db().execute(
      '''
INSERT INTO hidden_posts(id, user_id, post_id, created_at)
SELECT uuid(), ?1, ?2, ?3
WHERE NOT EXISTS (
  SELECT 1 FROM hidden_posts WHERE user_id = ?1 AND post_id = ?2
)''',
      [me, postId, DateTime.timestamp().toIso8601String()],
    );
  }

  @override
  Future<void> bookmarkPost({required String postId}) async {
    final me = currentUserId;
    if (me == null) return;
    // One transaction, like `like`: quick taps run one after the other.
    await _powerSyncRepository.db().writeTransaction((tx) async {
      final exists = await tx.getOptional(
        'SELECT 1 FROM saved_posts WHERE user_id = ? AND post_id = ?',
        [me, postId],
      );
      if (exists == null) {
        await tx.execute(
          '''
          INSERT INTO saved_posts(id, user_id, post_id, created_at)
            VALUES(uuid(), ?, ?, ?)
      ''',
          [me, postId, DateTime.timestamp().toIso8601String()],
        );
        return;
      }
      await tx.execute(
        'DELETE FROM saved_posts WHERE user_id = ? AND post_id = ?',
        [me, postId],
      );
    });
  }

  @override
  Stream<bool> isBookmarked({required String postId, String? userId}) {
    return _powerSyncRepository
        .db()
        .watch(
          '''
      SELECT EXISTS (
        SELECT 1
        FROM saved_posts
        WHERE user_id = ? AND post_id = ?
      )
''',
          parameters: [userId ?? currentUserId, postId],
        )
        .map((event) => (event.first.values.first! as int).isTrue);
  }

  @override
  Future<List<Post>> getSavedPosts({
    required int offset,
    required int limit,
  }) async {
    if (currentUserId == null) return [];
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT
  posts.id,
  posts.created_at,
  posts.caption,
  posts.media,
  posts.updated_at,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  saved_posts
  inner join posts on saved_posts.post_id = posts.id
  left join profiles p on posts.user_id = p.id
WHERE saved_posts.user_id = ?1 AND ${_visibleAuthorSql('posts.user_id')}
  AND ${_postReadySql('posts')}
ORDER BY saved_posts.created_at DESC LIMIT ?2 OFFSET ?3
    ''',
      [currentUserId, limit, offset],
    );
    final jsonListMedia = result.map((row) {
      final json = Map<String, dynamic>.from(row);
      return json['media'] as String;
    }).toList();

    final media = await _decodeMediaLists(jsonListMedia);

    final posts = <Post>[];
    for (var i = 0; i < result.length; i++) {
      final json = Map<String, dynamic>.from(result[i]);
      final post = Post.fromJson(
        json,
        media: List<Media>.from(media[i].map(Media.fromJson).toList()),
      );
      posts.add(post);
    }
    return posts;
  }

  @override
  Future<void> archivePost({required String postId}) async {
    if (currentUserId == null) return;
    final exists = await _powerSyncRepository.db().execute(
      'SELECT 1 FROM archived_posts WHERE user_id = ? AND post_id = ?',
      [currentUserId, postId],
    );
    if (exists.isEmpty) {
      await _powerSyncRepository.db().execute(
        '''
          INSERT INTO archived_posts(id, user_id, post_id, created_at)
            VALUES(uuid(), ?, ?, ?)
      ''',
        [currentUserId, postId, DateTime.timestamp().toIso8601String()],
      );
      return;
    }
    await _powerSyncRepository.db().execute(
      'DELETE FROM archived_posts WHERE user_id = ? AND post_id = ?',
      [currentUserId, postId],
    );
  }

  @override
  Stream<bool> isArchived({required String postId, String? userId}) {
    return _powerSyncRepository
        .db()
        .watch(
          '''
      SELECT EXISTS (
        SELECT 1
        FROM archived_posts
        WHERE user_id = ? AND post_id = ?
      )
''',
          parameters: [userId ?? currentUserId, postId],
        )
        .map((event) => (event.first.values.first! as int).isTrue);
  }

  @override
  Future<List<Post>> getArchivedPosts({
    required int offset,
    required int limit,
  }) async {
    if (currentUserId == null) return [];
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT
  posts.id,
  posts.created_at,
  posts.caption,
  posts.media,
  posts.updated_at,
  p.id as user_id,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM
  archived_posts
  inner join posts on archived_posts.post_id = posts.id
  left join profiles p on posts.user_id = p.id
WHERE archived_posts.user_id = ?1
ORDER BY archived_posts.created_at DESC LIMIT ?2 OFFSET ?3
    ''',
      [currentUserId, limit, offset],
    );
    final jsonListMedia = result.map((row) {
      final json = Map<String, dynamic>.from(row);
      return json['media'] as String;
    }).toList();

    final media = await _decodeMediaLists(jsonListMedia);

    final posts = <Post>[];
    for (var i = 0; i < result.length; i++) {
      final json = Map<String, dynamic>.from(result[i]);
      final post = Post.fromJson(
        json,
        media: List<Media>.from(media[i].map(Media.fromJson).toList()),
      );
      posts.add(post);
    }
    return posts;
  }

  @override
  Stream<int> followersCountOf({required String userId}) => _powerSyncRepository
      .db()
      .watch(
        'SELECT COUNT(*) AS subscription_count FROM subscriptions '
        // Only accepted follows count — a 'pending' request to a private
        // account must NOT bump the follower count until it's approved.
        // Legacy rows have NULL status and count as accepted.
        "WHERE subscribed_to_id = ? AND COALESCE(status, 'accepted') = 'accepted'",
        parameters: [userId],
      )
      .map(
        (event) =>
            event.safeMap((element) => element['subscription_count']).first
                as int,
      );

  @override
  Future<void> follow({
    required String followToId,
    String? followerId,
  }) async {
    final me = currentUserId;
    if (me == null) return;
    if (followToId == me) return;
    final follower = followerId ?? me;
    // Check and write in one transaction: two quick taps both saw "not
    // following" and inserted twice — the server had no unique pair, so the
    // follower count went up by two.
    await _powerSyncRepository.db().writeTransaction((tx) async {
      final exists = await tx.getOptional(
        'SELECT 1 FROM subscriptions '
        'WHERE subscriber_id = ? AND subscribed_to_id = ?',
        [follower, followToId],
      );
      if (exists == null) {
        // A private account is followed by REQUEST: the row lands as
        // 'pending' and only unlocks content once the owner accepts it. A
        // public account is followed outright ('accepted').
        final profile = await tx.getOptional(
          'SELECT is_private FROM profiles WHERE id = ?',
          [followToId],
        );
        final private = profile?['is_private'];
        final targetPrivate = private == 1 || private == true;
        await tx.execute(
          '''
          INSERT INTO subscriptions(id, subscriber_id, subscribed_to_id, status)
            VALUES(uuid(), ?, ?, ?)
      ''',
          [follower, followToId, targetPrivate ? 'pending' : 'accepted'],
        );
        return;
      }
      // Already following OR a request is pending — tapping again cancels
      // either (a plain delete works for both, so a request is withdrawn).
      await tx.execute(
        'DELETE FROM subscriptions '
        'WHERE subscriber_id = ? AND subscribed_to_id = ?',
        [follower, followToId],
      );
    });
  }

  @override
  Future<void> acceptFollowRequest({required String requesterId}) async {
    if (currentUserId == null) return;
    await _powerSyncRepository.db().execute(
      '''
        UPDATE subscriptions SET status = 'accepted'
        WHERE subscriber_id = ? AND subscribed_to_id = ? AND status = 'pending'
      ''',
      [requesterId, currentUserId],
    );
  }

  @override
  Future<void> declineFollowRequest({required String requesterId}) async {
    if (currentUserId == null) return;
    await _powerSyncRepository.db().execute(
      '''
        DELETE FROM subscriptions
        WHERE subscriber_id = ? AND subscribed_to_id = ? AND status = 'pending'
      ''',
      [requesterId, currentUserId],
    );
  }

  @override
  Stream<String> followState({required String userId, String? followerId}) {
    if (followerId == null && currentUserId == null) {
      return const Stream.empty();
    }
    return _powerSyncRepository
        .db()
        .watch(
          '''
    SELECT status FROM subscriptions
    WHERE subscriber_id = ? AND subscribed_to_id = ?
    ''',
          parameters: [followerId ?? currentUserId, userId],
        )
        .map(
          (event) => event.isEmpty
              ? 'none'
              // Rows written before the status column existed read as null;
              // treat those as an accepted follow.
              : (event.first['status'] as String?) ?? 'accepted',
        );
  }

  @override
  Future<void> unfollow({
    required String unfollowId,
    String? unfollowerId,
  }) async {
    if (currentUserId == null) return;
    await _powerSyncRepository.db().execute(
      '''
          DELETE FROM subscriptions WHERE subscriber_id = ? AND subscribed_to_id = ?
      ''',
      [unfollowerId ?? currentUserId, unfollowId],
    );
  }

  @override
  Future<void> removeFollower({required String id}) async {
    if (currentUserId == null) return;
    await _powerSyncRepository.db().execute(
      '''
          DELETE FROM subscriptions WHERE subscriber_id = ? AND subscribed_to_id = ?
      ''',
      [id, currentUserId],
    );
  }

  @override
  Stream<int> followingsCountOf({
    required String userId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT COUNT(*) AS subscription_count FROM subscriptions '
        // Only accepted follows count toward "following" — a pending request
        // to a private account doesn't yet. NULL status = legacy = accepted.
        "WHERE subscriber_id = ? AND COALESCE(status, 'accepted') = 'accepted'",
        parameters: [userId],
      )
      .map(
        (event) =>
            event.safeMap((element) => element['subscription_count']).first
                as int,
      );

  @override
  Future<List<User>> getFollowers({String? userId}) async {
    final rows = await _powerSyncRepository.db().getAll(
      _followListSql(followers: true, limited: false),
      [userId ?? currentUserId],
    );
    return rows.safeMap(User.fromJson).toList(growable: false);
  }

  /// The people following [?1] ([followers]) or followed by them, with their
  /// profiles, newest follow first — one query. It used to fetch the ids,
  /// then each profile with its own query, in no particular order. A private
  /// account's list only shows to its followers, and blocked people are left
  /// out of anyone's list. [limited]: `LIMIT ?2`, for scroll pagination.
  String _followListSql({required bool followers, required bool limited}) {
    final person = followers ? 's.subscriber_id' : 's.subscribed_to_id';
    final owner = followers ? 's.subscribed_to_id' : 's.subscriber_id';
    return '''
SELECT p.*
FROM subscriptions s
  JOIN profiles p ON p.id = $person
WHERE $owner = ?1
  AND COALESCE(s.status, 'accepted') = 'accepted'
  AND ${_visibleAuthorSql('?1')}
  AND ${_notBlockedSql(person)}
ORDER BY s.created_at DESC
${limited ? 'LIMIT ?2' : ''}''';
  }

  @override
  Future<void> clearPushTokenOnServer() async {
    final id = currentUserId;
    if (id == null) return;
    await _powerSyncRepository
        .postgrest()
        .from('profiles')
        .update({'push_token': ''})
        .eq('id', id);
  }

  @override
  Stream<Map<String, User>> profilesOf({required List<String> ids}) {
    if (ids.isEmpty) return Stream.value(const {});
    return _powerSyncRepository
        .db()
        .watch(
          'SELECT id, avatar_url, username, full_name FROM profiles '
          'WHERE id IN (SELECT value FROM json_each(?1))',
          parameters: [jsonEncode(ids)],
        )
        .map(
          (rows) => {
            for (final row in rows) row['id'] as String: User.fromJson(row),
          },
        );
  }

  @override
  Future<List<User>> profilesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final result = await _powerSyncRepository.db().getAll(
      'SELECT id, avatar_url, username, full_name '
      'FROM profiles WHERE id IN ($placeholders)',
      ids,
    );
    return result.safeMap(User.fromJson).toList(growable: false);
  }

  @override
  Stream<List<User>> followers({required String userId, int? limit}) =>
      // `limit` caps the live window; growing it re-subscribes wider.
      _powerSyncRepository
          .db()
          .watch(
            _followListSql(followers: true, limited: limit != null),
            parameters: [userId, if (limit != null) limit],
          )
          .map((rows) => rows.safeMap(User.fromJson).toList(growable: false));

  @override
  Future<List<User>> getFollowings({String? userId, int? limit}) async {
    // `limit` caps how many are fetched; callers grow it for scroll
    // pagination. Null = all.
    final rows = await _powerSyncRepository.db().getAll(
      _followListSql(followers: false, limited: limit != null),
      [userId ?? currentUserId, if (limit != null) limit],
    );
    return rows.safeMap(User.fromJson).toList(growable: false);
  }

  @override
  Future<bool> isFollowed({
    required String userId,
    String? followerId,
  }) async {
    final result = await _powerSyncRepository.db().execute(
      '''
    SELECT 1 FROM subscriptions WHERE subscriber_id = ? AND subscribed_to_id = ?
    ''',
      [followerId ?? currentUserId, userId],
    );
    return result.isNotEmpty;
  }

  @override
  Stream<bool> followingStatus({
    required String userId,
    String? followerId,
  }) {
    if (followerId == null && currentUserId == null) {
      return const Stream.empty();
    }
    return _powerSyncRepository
        .db()
        .watch(
          '''
    SELECT 1 FROM subscriptions
    WHERE subscriber_id = ? AND subscribed_to_id = ?
      AND (status = 'accepted' OR status IS NULL)
    ''',
          parameters: [followerId ?? currentUserId, userId],
        )
        .map((event) => event.isNotEmpty);
  }

  @override
  Stream<int> commentsAmountOf({required String postId}) => _powerSyncRepository
      .db()
      .watch(
        '''
SELECT COUNT(*) AS comments_count FROM comments
WHERE post_id = ? AND ${_notBlockedSql('comments.user_id')}
''',
        parameters: [postId],
      )
      .map(
        (result) => result.map((row) => row['comments_count']).first as int,
      );

  @override
  Stream<List<Comment>> commentsOf({required String postId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT 
  c1.*,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name,
  COUNT(c2.id) AS replies
FROM 
  comments c1
  INNER JOIN
    profiles p ON p.id = c1.user_id
  LEFT JOIN
    comments c2 ON c1.id = c2.replied_to_comment_id
      AND ${_notBlockedSql('c2.user_id')}
WHERE
  c1.post_id = ? AND c1.replied_to_comment_id IS NULL
  AND ${_notBlockedSql('c1.user_id')}
GROUP BY
    c1.id, p.avatar_url, p.username, p.full_name
ORDER BY created_at ASC
''',
            parameters: [postId],
          )
          .map(
            (result) => result.safeMap(Comment.fromRow).toList(growable: false),
          );

  @override
  Future<void> createComment({
    required String postId,
    required String userId,
    required String content,
    String? repliedToCommentId,
  }) => _powerSyncRepository.db().execute(
    '''
INSERT INTO
  comments(id, post_id, user_id, content, created_at, replied_to_comment_id)
VALUES(uuid(), ?, ?, ?, ?, ?)
''',
    [
      postId,
      userId,
      content,
      DateTime.timestamp().toIso8601String(),
      repliedToCommentId,
    ],
  );

  @override
  Future<void> deleteComment({required String id}) =>
      _powerSyncRepository.db().execute(
        '''
DELETE FROM comments
WHERE id = ?
''',
        [id],
      );

  @override
  Stream<List<Comment>> repliedCommentsOf({required String commentId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT 
  c1.*,
  p.avatar_url as avatar_url,
  p.username as username,
  p.full_name as full_name
FROM 
  comments c1
  INNER JOIN
    profiles p ON p.id = c1.user_id
WHERE
  c1.replied_to_comment_id = ? AND ${_notBlockedSql('c1.user_id')}
GROUP BY
    c1.id, p.avatar_url, p.username, p.full_name
ORDER BY created_at ASC
''',
            parameters: [commentId],
          )
          .map(
            (result) => result.safeMap(Comment.fromRow).toList(growable: false),
          );

  @override
  Future<void> updateUser({
    String? fullName,
    String? email,
    String? username,
    String? avatarUrl,
    String? pushToken,
    String? bio,
    String? birthday,
    String? telegram,
    String? website,
    String? instagram,
    String? gender,
    String? password,
    String? lang,
    bool clearAvatar = false,
  }) async {
    // Writes straight to the `profiles` table (PowerSync uploads the change).
    // The Supabase user-metadata path is gone; identity/password live in Entra.
    final userId = currentUserId;
    if (userId == null) return;
    // `null` means "leave alone" for every field here, so removing a value
    // needs its own flag — otherwise an avatar can be replaced but never
    // taken off.
    final fields = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (username != null) 'username': username,
      if (clearAvatar)
        'avatar_url': null
      else if (avatarUrl != null)
        'avatar_url': avatarUrl,
      if (pushToken != null) 'push_token': pushToken,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (birthday != null) 'birthday': birthday,
      if (telegram != null) 'telegram': telegram,
      if (website != null) 'website': website,
      if (instagram != null) 'instagram': instagram,
      if (gender != null) 'gender': gender,
      if (lang != null) 'lang': lang,
    };
    if (fields.isEmpty) return;
    final setClause = fields.keys.map((k) => '$k = ?').join(', ');
    await _powerSyncRepository.db().execute(
      'UPDATE profiles SET $setClause WHERE id = ?',
      [...fields.values, userId],
    );
  }

  @override
  Future<void> completeOnboarding() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _powerSyncRepository.db().execute(
      'UPDATE profiles SET onboarded_at = ? WHERE id = ?',
      [DateTime.now().toUtc().toIso8601String(), userId],
    );
  }

  @override
  Future<void> updateUserBio({
    required String userId,
    required String bio,
  }) => _powerSyncRepository.db().execute(
    'UPDATE profiles SET bio = ? WHERE id = ?',
    [bio, userId],
  );

  @override
  Future<void> blockUser({
    required String userId,
    required String blockedId,
  }) async {
    final exists = await _powerSyncRepository.db().getOptional(
      'SELECT 1 FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
      [userId, blockedId],
    );
    if (exists == null) {
      await _powerSyncRepository.db().execute(
        '''
INSERT INTO blocked_users(id, blocker_id, blocked_id, created_at)
VALUES(?, ?, ?, ?)''',
        [uuid.v4(), userId, blockedId, JiffyX.now()],
      );
    }
    // A block ends the follow both ways (and any pending request), as the
    // block dialog says. Its own statement, so the block above stands even if
    // this part were ever refused by the server.
    await _powerSyncRepository.db().execute(
      '''
DELETE FROM subscriptions
WHERE (subscriber_id = ?1 AND subscribed_to_id = ?2)
   OR (subscriber_id = ?2 AND subscribed_to_id = ?1)''',
      [userId, blockedId],
    );
  }

  @override
  Future<void> unblockUser({
    required String userId,
    required String blockedId,
  }) => _powerSyncRepository.db().execute(
    'DELETE FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
    [userId, blockedId],
  );

  @override
  Stream<bool> isBlocked({
    required String userId,
    required String otherUserId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT 1 FROM blocked_users WHERE blocker_id = ? AND blocked_id = ?',
        parameters: [userId, otherUserId],
      )
      .map((rows) => rows.isNotEmpty);

  @override
  Stream<Set<String>> blockedPeersOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT blocked_id AS peer FROM blocked_users WHERE blocker_id = ?1
UNION
SELECT blocker_id FROM blocked_users WHERE blocked_id = ?1''',
            parameters: [userId],
          )
          .map((rows) => {for (final row in rows) row['peer'] as String});

  @override
  Stream<List<User>> blockedUsers({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT p.* FROM blocked_users b
INNER JOIN profiles p ON p.id = b.blocked_id
WHERE b.blocker_id = ?
ORDER BY b.created_at DESC''',
            parameters: [userId],
          )
          .map((rows) => rows.map(User.fromJson).toList());

  @override
  Future<void> changePassword({required String newPassword}) async {
    // Password changes are handled by Microsoft Entra's hosted flow (the
    // "Forgot password?" link on the sign-in page), not in-app.
    throw UnsupportedError(
      'Password changes are handled on the Entra sign-in page.',
    );
  }

  @override
  Future<void> updatePrivacy({
    required String userId,
    required bool isPrivate,
  }) => _powerSyncRepository.db().execute(
    'UPDATE profiles SET is_private = ? WHERE id = ?',
    [isPrivate ? 1 : 0, userId],
  );

  @override
  Future<List<User>> searchUsers({
    required int limit,
    required int offset,
    required String? query,
    String? userId,
    String? excludeUserIds,
  }) async {
    if (query == null || _searchKey(query).isEmpty) return <User>[];
    final me = currentUserId;

    // Server-first, so EVERY account is findable, not just the profiles
    // already synced to this device. `search_profiles` matches a search key of
    // the query against usernames and names (Cyrillic and Latin alike, see
    // oci-backend/sql/search_profiles.sql) and takes the query as a parameter.
    // Falls back to the same match on the local profiles when offline.
    try {
      final rows = await _powerSyncRepository.postgrest().rpc<List<dynamic>>(
        'search_profiles',
        params: {'p_query': query, 'p_limit': limit, 'p_offset': offset},
      );
      // The server doesn't know about blocks yet; drop them here, both ways.
      final blocked = await _blockedPeerIds();
      return rows
          .cast<Map<String, dynamic>>()
          .map(User.fromJson)
          .where((user) => user.id != me && !blocked.contains(user.id))
          .toList(growable: false);
    } catch (_) {
      // Offline / server error — fall back to the local synced profiles.
    }

    final excludeUserIdsStatement = excludeUserIds == null
        ? ''
        : 'AND id NOT IN ($excludeUserIds)';
    final rows = await _powerSyncRepository.db().getAll(
      '''
SELECT id, avatar_url, full_name, username
  FROM profiles
WHERE id <> ?1 $excludeUserIdsStatement
  AND ${_notBlockedSql('profiles.id')}
''',
      [currentUserId],
    );
    final key = _searchKey(query);
    bool startsWith(Row row) =>
        _searchKey(row['username'] as String? ?? '').startsWith(key) ||
        _searchKey(row['full_name'] as String? ?? '').startsWith(key);
    final matches =
        rows
            .where(
              (row) =>
                  _searchKey(row['username'] as String? ?? '').contains(key) ||
                  _searchKey(row['full_name'] as String? ?? '').contains(key),
            )
            .toList()
          ..sort((a, b) {
            final byStart = (startsWith(b) ? 1 : 0) - (startsWith(a) ? 1 : 0);
            if (byStart != 0) return byStart;
            return (a['username'] as String? ?? '').compareTo(
              b['username'] as String? ?? '',
            );
          });
    return matches
        .skip(offset)
        .take(limit)
        .map(User.fromJson)
        .toList(growable: false);
  }

  /// The search key of [text]: lower-cased, whitespace collapsed, apostrophes
  /// dropped, Cyrillic (Russian and Uzbek) spelled in Latin and the common
  /// double spellings folded (kh / x -> h, zh -> j) — so "Шаҳзод", "Shakhzod"
  /// and "shahzod" all match. Must stay in step with `search_key` in
  /// oci-backend/sql/search_profiles.sql.
  static String _searchKey(String text) {
    var s = text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    for (final MapEntry(:key, :value) in _cyrillicDigraphs.entries) {
      s = s.replaceAll(key, value);
    }
    final out = StringBuffer();
    for (final rune in s.runes) {
      final char = String.fromCharCode(rune);
      final latin = _cyrillicLetters[char];
      if (latin != null) {
        out.write(latin);
      } else if (!_droppedInSearch.contains(char)) {
        out.write(char);
      }
    }
    return out
        .toString()
        .replaceAll('kh', 'h')
        .replaceAll('zh', 'j')
        .replaceAll('x', 'h');
  }

  static const _cyrillicDigraphs = {
    'щ': 'sh',
    'ш': 'sh',
    'ч': 'ch',
    'ц': 'ts',
    'ю': 'yu',
    'я': 'ya',
    'ё': 'yo',
    'ж': 'j',
    'х': 'h',
    'ҳ': 'h',
  };

  static const _cyrillicLetters = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'з': 'z', //
    'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', //
    'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'ы': 'i', //
    'э': 'e', 'ў': 'o', 'қ': 'q', 'ғ': 'g',
  };

  static const _droppedInSearch = {'ъ', 'ь', "'", '’', 'ʻ', 'ʼ', '`'};

  @override
  Future<List<User>> suggestedUsers({int limit = 50}) async {
    final me = currentUserId;
    if (me == null) return <User>[];
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT id, avatar_url, full_name, username, bio, is_private
FROM profiles
WHERE id <> ?1
  AND id NOT IN (
    SELECT subscribed_to_id FROM subscriptions WHERE subscriber_id = ?1
  )
  AND ${_notBlockedSql('profiles.id')}
LIMIT ?2
''',
      [me, limit],
    );
    return result.safeMap(User.fromJson).toList(growable: false);
  }

  @override
  Future<void> createStory({
    required User author,
    required StoryContentType contentType,
    required String contentUrl,
    String? id,
    int? duration,
    String? locationName,
    double? locationLat,
    double? locationLng,
  }) => _powerSyncRepository.db().execute(
    '''
insert into stories (id, user_id, content_type, content_url, duration, created_at, expires_at, location_name, location_lat, location_lng)
values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
    [
      id ?? uuid.v4(),
      author.id,
      contentType.toJson(),
      contentUrl,
      duration,
      DateTime.timestamp().toIso8601String(),
      DateTime.timestamp().add(1.days).toIso8601String(),
      locationName,
      locationLat,
      locationLng,
    ],
  );

  @override
  Future<void> deleteStory({required String id}) =>
      _powerSyncRepository.db().execute(
        '''
DELETE FROM stories WHERE id = ?
''',
        [id],
      );

  @override
  Future<void> recordStoryView({
    required String storyId,
    required String viewerId,
  }) async {
    final already = await _powerSyncRepository.db().getOptional(
      'SELECT 1 FROM story_views WHERE story_id = ? AND user_id = ?',
      [storyId, viewerId],
    );
    if (already != null) return;
    await _powerSyncRepository.db().execute(
      'INSERT INTO story_views (id, story_id, user_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [uuid.v4(), storyId, viewerId, DateTime.timestamp().toIso8601String()],
    );
  }

  @override
  Stream<int> storyViewsCountOf({required String storyId}) =>
      _powerSyncRepository
          .db()
          .watch(
            'SELECT COUNT(*) AS c FROM story_views WHERE story_id = ?',
            parameters: [storyId],
          )
          .map((rows) => (rows.first['c'] as int?) ?? 0);

  @override
  Stream<List<User>> storyViewersOf({required String storyId, int? limit}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT p.* FROM story_views sv
  JOIN profiles p ON p.id = sv.user_id
WHERE sv.story_id = ? AND ${_notBlockedSql('sv.user_id')}
ORDER BY sv.created_at DESC
${limit != null ? 'LIMIT ?' : ''}
''',
            parameters: [storyId, if (limit != null) limit],
          )
          .map((rows) => rows.map(User.fromJson).toList(growable: false));

  @override
  Future<void> likeStory({
    required String storyId,
    required String userId,
  }) async {
    final already = await _powerSyncRepository.db().getOptional(
      'SELECT id FROM story_likes WHERE story_id = ? AND user_id = ?',
      [storyId, userId],
    );
    if (already != null) {
      await _powerSyncRepository.db().execute(
        'DELETE FROM story_likes WHERE id = ?',
        [already['id']],
      );
      return;
    }
    await _powerSyncRepository.db().execute(
      'INSERT INTO story_likes (id, story_id, user_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [uuid.v4(), storyId, userId, DateTime.timestamp().toIso8601String()],
    );
  }

  @override
  Stream<bool> isStoryLiked({
    required String storyId,
    required String userId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT EXISTS(SELECT 1 FROM story_likes '
        'WHERE story_id = ? AND user_id = ?) AS liked',
        parameters: [storyId, userId],
      )
      .map((rows) => (rows.first['liked'] as int? ?? 0) == 1);

  @override
  Stream<int> storyLikesCountOf({required String storyId}) =>
      _powerSyncRepository
          .db()
          .watch(
            'SELECT COUNT(*) AS c FROM story_likes WHERE story_id = ?',
            parameters: [storyId],
          )
          .map((rows) => (rows.first['c'] as int?) ?? 0);

  @override
  Stream<List<Story>> activeStories() => _powerSyncRepository
      .db()
      .watch(
        '''
SELECT s.*
FROM stories s
WHERE s.expires_at > current_timestamp
  AND ${_visibleAuthorSql('s.user_id')}
ORDER BY s.created_at ASC
''',
      )
      .map((event) => event.safeMap(Story.fromJson).toList(growable: false));

  @override
  Stream<List<Story>> getStories({
    required String userId,
    bool includeAuthor = true,
  }) => _powerSyncRepository
      .db()
      .watch(
        '''
SELECT
  s.*${includeAuthor ? ', p.id as user_id, p.username, p.full_name, p.avatar_url' : ''}
FROM stories s
  ${includeAuthor ? 'LEFT JOIN profiles p ON s.user_id = p.id' : ''}
WHERE s.user_id = ? AND s.expires_at > current_timestamp
  AND ${_visibleAuthorSql('s.user_id')}
ORDER BY s.created_at ASC
''',
        parameters: [userId],
      )
      .map((event) => event.safeMap(Story.fromJson).toList(growable: false));

  @override
  Stream<List<String>> followingsWithActiveStories({String? userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT DISTINCT s.user_id AS user_id
FROM stories s
  INNER JOIN subscriptions f ON f.subscribed_to_id = s.user_id
WHERE f.subscriber_id = ? AND s.expires_at > current_timestamp
  AND COALESCE(f.status, 'accepted') = 'accepted'
  AND ${_visibleAuthorSql('s.user_id')}
''',
            parameters: [userId ?? currentUserId],
          )
          .map(
            (rows) => rows
                .map((row) => row['user_id'] as String)
                .toList(growable: false),
          );

  @override
  Future<Story?> getStoryBy({required String id}) async {
    final row = await _powerSyncRepository.db().getOptional(
      '''
SELECT s.*, p.id as user_id, p.username, p.full_name, p.avatar_url
FROM stories s
  LEFT JOIN profiles p ON s.user_id = p.id
WHERE s.id = ? AND ${_visibleAuthorSql('s.user_id')}
''',
      [id],
    );
    if (row == null) return null;
    return Story.fromJson(row);
  }

  @override
  Stream<List<Story>> archivedStoriesOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT s.*, p.id as user_id, p.username, p.full_name, p.avatar_url
FROM stories s
  LEFT JOIN profiles p ON s.user_id = p.id
WHERE s.user_id = ?
ORDER BY s.created_at DESC
''',
            parameters: [userId],
          )
          .map(
            (event) => event.safeMap(Story.fromJson).toList(growable: false),
          );

  @override
  Stream<List<Story>> locationStoriesOf({
    required String userId,
    required String regionIso,
    double? lat,
    double? lng,
    double radiusDegrees = 0.0002,
  }) {
    // A pin and a whole region are the same table, told apart by whether the
    // row carries coordinates — so the point view never picks up region pins
    // sitting at some unrelated spot. The radius is tight (~22 m): a story pin
    // is an exact point, so two distinct pins in one region stay separate.
    final scoped = lat != null && lng != null;
    return _powerSyncRepository
        .db()
        .watch(
          '''
SELECT s.*, p.id as user_id, p.username, p.full_name, p.avatar_url
FROM location_stories ls
  INNER JOIN stories s ON s.id = ls.story_id
  LEFT JOIN profiles p ON s.user_id = p.id
WHERE ls.user_id = ?1 AND ls.region_iso = ?2
  -- Only the place owner's own stories (the server now refuses pinning
  -- anyone else's; this ignores any pinned in before), like highlights.
  AND s.user_id = ls.user_id
  AND ${_visibleAuthorSql('s.user_id')}
  ${scoped ? 'AND ls.lat IS NOT NULL AND ABS(ls.lat - ?3) <= ?4 '
                    'AND ls.lng IS NOT NULL AND ABS(ls.lng - ?5) <= ?4' : ''}
ORDER BY ls.created_at DESC
''',
          parameters: [
            userId,
            regionIso,
            if (scoped) ...[lat, radiusDegrees, lng],
          ],
        )
        .map((event) => event.safeMap(Story.fromJson).toList(growable: false));
  }

  @override
  Future<void> pinStoryToLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  }) async {
    // SELECT-then-INSERT rather than ON CONFLICT: the local PowerSync tables
    // carry no unique index for the conflict target to resolve against.
    final existing = await _powerSyncRepository.db().getAll(
      '''
SELECT id FROM location_stories
WHERE user_id = ?1 AND story_id = ?2 AND region_iso = ?3
  AND ((lat IS NULL AND ?4 IS NULL) OR lat = ?4)
  AND ((lng IS NULL AND ?5 IS NULL) OR lng = ?5)
''',
      [userId, storyId, regionIso, lat, lng],
    );
    if (existing.isNotEmpty) return;
    await _powerSyncRepository.db().execute(
      '''
INSERT INTO location_stories (id, user_id, story_id, region_iso, lat, lng, created_at)
VALUES (uuid(), ?1, ?2, ?3, ?4, ?5, ?6)
''',
      [
        userId,
        storyId,
        regionIso,
        lat,
        lng,
        DateTime.timestamp().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> pinStory({
    required String userId,
    required String storyId,
    required String regionIso,
    required double lat,
    required double lng,
    String? placeName,
    String? highlightId,
    String? newHighlightName,
    String? coverUrl,
  }) => _powerSyncRepository.db().writeTransaction((tx) async {
    final now = DateTime.timestamp().toIso8601String();
    final pinned = await tx.getOptional(
      'SELECT id FROM location_stories WHERE user_id = ?1 AND story_id = ?2 '
      'AND region_iso = ?3 AND lat = ?4 AND lng = ?5',
      [userId, storyId, regionIso, lat, lng],
    );
    if (pinned == null) {
      await tx.execute(
        'INSERT INTO location_stories '
        '(id, user_id, story_id, region_iso, lat, lng, created_at) '
        'VALUES (uuid(), ?1, ?2, ?3, ?4, ?5, ?6)',
        [userId, storyId, regionIso, lat, lng, now],
      );
    }
    // The name labels the pin on the map; a blank one keeps the old label.
    final name = placeName?.trim();
    if (name != null && name.isNotEmpty) {
      await tx.execute(
        'UPDATE stories SET location_lat = ?, location_lng = ?, '
        'location_name = ? WHERE id = ?',
        [lat, lng, name, storyId],
      );
    } else {
      await tx.execute(
        'UPDATE stories SET location_lat = ?, location_lng = ? WHERE id = ?',
        [lat, lng, storyId],
      );
    }
    if (highlightId != null) {
      final item = await tx.getOptional(
        'SELECT id FROM story_highlight_items '
        'WHERE highlight_id = ? AND story_id = ?',
        [highlightId, storyId],
      );
      if (item == null) {
        await tx.execute(
          'INSERT INTO story_highlight_items '
          '(id, highlight_id, story_id, created_at) VALUES (?, ?, ?, ?)',
          [uuid.v4(), highlightId, storyId, now],
        );
      }
    }
    if (newHighlightName != null) {
      final newId = uuid.v4();
      await tx.execute(
        'INSERT INTO story_highlights '
        '(id, user_id, name, cover_url, created_at) VALUES (?, ?, ?, ?, ?)',
        [newId, userId, newHighlightName, coverUrl, now],
      );
      await tx.execute(
        'INSERT INTO story_highlight_items '
        '(id, highlight_id, story_id, created_at) VALUES (?, ?, ?, ?)',
        [uuid.v4(), newId, storyId, now],
      );
    }
  });

  @override
  Future<String?> savedRegionNear({
    required String userId,
    required double lat,
    required double lng,
  }) async {
    final row = await _powerSyncRepository.db().getOptional(
      '''
SELECT region_iso AS iso FROM location_stories
WHERE user_id = ?1 AND region_iso IS NOT NULL AND lat IS NOT NULL
  AND ABS(lat - ?2) <= ?4 AND ABS(lng - ?3) <= ?4
UNION ALL
SELECT location_region FROM posts
WHERE user_id = ?1 AND location_region IS NOT NULL
  AND location_lat IS NOT NULL
  AND ABS(location_lat - ?2) <= ?4 AND ABS(location_lng - ?3) <= ?4
LIMIT 1
''',
      [userId, lat, lng, _pinRadiusDegrees],
    );
    final iso = row?['iso'] as String?;
    return iso == null || iso.isEmpty ? null : iso;
  }

  @override
  Future<void> unpinStoryFromLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  }) => _powerSyncRepository.db().execute(
    // The pins that put the story on this page: near the point, by the same
    // radius the page lists them with — or, on a whole region's page (no
    // point), all of them in the region. It matched lat/lng exactly and NULL
    // only with NULL, so on a region's page it never matched anything.
    '''
DELETE FROM location_stories
WHERE user_id = ?1 AND story_id = ?2 AND region_iso = ?3
  AND (?4 IS NULL OR (lat IS NOT NULL AND ABS(lat - ?4) <= ?6))
  AND (?5 IS NULL OR (lng IS NOT NULL AND ABS(lng - ?5) <= ?6))
''',
    [userId, storyId, regionIso, lat, lng, _pinRadiusDegrees],
  );

  /// How near a pin has to be to a place's point to count as there; the
  /// place pages list pins with the same default radius.
  static const double _pinRadiusDegrees = 0.0002;

  @override
  Future<String> uploadStoryMedia({
    required String storyId,
    required File imageFile,
    required Uint8List imageBytes,
  }) async {
    final stories = MediaStorage.instance.from('stories');
    final extension = imageFile.path.split('.').last.toLowerCase();
    // `image/jpg` is not a registered MIME type; stories are now JPEGs.
    final imageExtension = extension == 'jpg' ? 'jpeg' : extension;
    final imagePath = '$storyId/image';

    final storedPath = await stories.uploadBinary(
      imagePath,
      imageBytes,
      fileOptions: MediaFileOptions(
        contentType: 'image/$imageExtension',
        cacheControl: '9000000',
      ),
    );
    return stories.getPublicUrl(storedPath);
  }

  @override
  Future<List<User>> getPostLikers({
    required String postId,
    int limit = 30,
    int offset = 0,
  }) async {
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT up.id, up.username, up.full_name, up.avatar_url
FROM profiles up
INNER JOIN likes l ON up.id = l.user_id
WHERE l.post_id = ? AND ${_notBlockedSql('up.id')}
LIMIT ? OFFSET ?
''',
      [postId, limit, offset],
    );
    if (result.isEmpty) return [];
    return result.safeMap(User.fromJson).toList(growable: false);
  }

  @override
  Future<List<User>> getPostLikersInFollowings({
    required String postId,
    int limit = 3,
    int offset = 0,
  }) async {
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT id, avatar_url, username, full_name
FROM profiles
WHERE id IN (
    SELECT l.user_id
    FROM likes l
    WHERE l.post_id = ?1
    AND EXISTS (
        SELECT *
        FROM subscriptions f
        WHERE f.subscribed_to_id = l.user_Id
        AND f.subscriber_id = ?2
        AND COALESCE(f.status, 'accepted') = 'accepted'
    ) AND id <> ?2
)
  AND ${_notBlockedSql('profiles.id')}
LIMIT ?3 OFFSET ?4
''',
      [postId, currentUserId, limit, offset],
    );
    if (result.isEmpty) return [];
    return result.safeMap(User.fromJson).toList(growable: false);
  }
}

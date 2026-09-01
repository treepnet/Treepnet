import 'dart:async';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:database_client/src/invite_badge.dart';
import 'package:powersync_repository/powersync_repository.dart';
import 'package:shared/shared.dart';
import 'package:user_repository/user_repository.dart';

/// User base repository.
abstract class UserBaseRepository {
  /// The id of the currently authenticated user.
  String? get currentUserId;

  /// Broadcasts the user profile identified by [id].
  Stream<User> profile({required String id});

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
  Future<List<User>> getFollowings({String? userId});

  /// Broadcasts a list of followers of the user identified by [userId].
  Stream<List<User>> followers({required String userId});

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

  /// Likes the post by provided either post or comment [id].
  Future<void> like({
    required String id,
    bool post = true,
  });

  /// Returns a real-time stream of likes count of post by provided [id].
  Stream<int> likesOf({
    required String id,
    bool post = true,
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

  /// Returns a real-time stream of whether the post identified by [postId] is
  /// archived by the user identified by [userId].
  Stream<bool> isArchived({required String postId, String? userId});

  /// Returns the page of posts archived by the currently authenticated user
  /// with provided [offset] and [limit].
  Future<List<Post>> getArchivedPosts({
    required int offset,
    required int limit,
  });

  /// Returns the page of posts with provided [offset] and [limit].
  Future<List<Post>> getPage({
    required int offset,
    required int limit,
    bool onlyReels = false,
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
  /// number of posts [userId] has placed there — used to shade each region on
  /// the travel map by post density.
  Stream<Map<String, int>> visitedRegionCountsOf({required String userId});

  /// Returns a real-time stream of the exact `(lat, lng)` of every post by
  /// [userId] that has a picked location — one marker per post on the map.
  Stream<List<({double lat, double lng, String? name})>> visitedPointsOf({
    required String userId,
  });

  /// Returns a real-time stream of the `(lat, lng, name)` of every story by
  /// [userId] that was pinned to a location. Ignores `expires_at`, so a pin
  /// stays on the map even after the 24h story itself has expired.
  Stream<List<({double lat, double lng, String? name})>> storyPointsOf({
    required String userId,
  });

  /// Deletes the post with provided [id].
  /// Returns the optional `id` of the deleted post.
  Future<String?> deletePost({required String id});

  /// Updates the post with provided [id] and optional parameters to update.
  Future<Post?> updatePost({required String id, String? caption});

  /// Returns the stream of real-time posts of the current user.
  Stream<List<Post>> postsOf({String? userId});

  /// Posts by [userId] placed in the ISO 3166-2 region [iso].
  Stream<List<Post>> postsInRegion({required String userId, required String iso});

  /// Posts by [userId] placed within [radiusDegrees] of ([lat], [lng]).
  ///
  /// A radius rather than an exact match: each post's pin is dropped by hand,
  /// so two posts from the same spot never carry identical coordinates.
  Stream<List<Post>> postsAtPoint({
    required String userId,
    required double lat,
    required double lng,
    double radiusDegrees = 0.02,
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

  /// Shares the post with the user identified by [receiver].
  Future<void> sharePost({
    required String id,
    required User sender,
    required User receiver,
    required Message sharedPostMessage,
    Message? message,
    PostAuthor? postAuthor,
  });
}

/// Abstract base class for a chats repository.
abstract class ChatsBaseRepository {
  /// Returns a stream of real-time chats of the user identified by [userId].
  Stream<List<ChatInbox>> chatsOf({required String userId});

  /// Streams the total number of unread incoming messages across every
  /// conversation the user identified by [userId] participates in.
  Stream<int> unreadMessagesCount({required String userId});

  /// Returns a stream of real-time messages of the chat identified by [chatId].
  Stream<List<Message>> messagesOf({required String chatId});

  /// Fetches a list of messages of the chat identified by [chatId].
  Future<List<Message>> getMessages({
    required String chatId,
    required int limit,
    required int offset,
  });

  /// Fetches a message with provided [messageId].
  Future<Message?> getRepliedMessage({required String messageId});

  /// Creates and send message with provided data. After sending the message
  /// the notification is sent to the user, identified by [receiver]'s `id`.
  Future<void> sendMessage({
    required String chatId,
    required User sender,
    required User receiver,
    required Message message,
    PostAuthor? postAuthor,
  });

  /// Deletes the message with provided [messageId].
  Future<void> deleteMessage({required String messageId});

  /// Deletes the chat with provided [chatId] and participant from the chat,
  /// identified by [userId].
  Future<void> deleteChat({required String chatId, required String userId});

  /// Creates a new chat with provided [userId] and [participantId], or returns
  /// the existing one. Returns the conversation id either way.
  Future<String> createChat({
    required String userId,
    required String participantId,
  });

  /// Marks the message as read by [messageId].
  Future<void> readMessage({
    required String messageId,
  });

  /// Marks every incoming unread message in [chatId] as read (called on open).
  Future<void> markConversationRead({
    required String chatId,
    required String userId,
  });

  /// The other participant's synced "last read" time in [conversationId] —
  /// drives ✓✓ read receipts. Null if they've not read anything.
  Stream<DateTime?> otherReadAtOf({
    required String conversationId,
    required String excludeUserId,
  });

  /// Upserts a typing heartbeat for [userId] in [conversationId] (call while
  /// typing, throttled).
  Future<void> setTyping({
    required String conversationId,
    required String userId,
  });

  /// The most recent typing heartbeat in [conversationId] from anyone other
  /// than [excludeUserId] — null if no one else is typing. The reader decides
  /// freshness (a heartbeat older than a few seconds means "stopped typing").
  Stream<DateTime?> typingUpdatedAtOf({
    required String conversationId,
    required String excludeUserId,
  });

  /// Edits the message with provided [oldMessage] and [newMessage].
  Future<void> editMessage({
    required Message oldMessage,
    required Message newMessage,
  });
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
    double radiusDegrees = 0.02,
  });

  /// Pins [storyId] to a place. Doing it twice is a no-op.
  Future<void> pinStoryToLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
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
  Stream<List<User>> storyViewersOf({required String storyId});

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
    implements
        UserBaseRepository,
        PostsBaseRepository,
        ChatsBaseRepository,
        StoriesBaseRepository {
  /// {@macro database_client}
  const DatabaseClient();

  /// Permanently deletes the current account and every row it owns from the
  /// database. Identifies the caller from the signed-in JWT, so it takes no
  /// arguments. Irreversible.
  Future<void> deleteAccount();

  /// Watches the messages of a conversation and invokes [callback] with a
  /// per-row change (new/old record) each time a message is inserted, updated
  /// or deleted — driven by PowerSync's reactive local database.
  ///
  /// It allows to update the UI in real time, without rebuilding the whole
  /// list of messages. Cancel the returned subscription to stop listening.
  StreamSubscription<void> onMessagesUpdates({
    required String conversationId,
    required ValueSetter<
      ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord})
    >
    callback,
  });
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
  StreamSubscription<void> onMessagesUpdates({
    required String conversationId,
    required ValueSetter<
      ({Map<String, dynamic> newRecord, Map<String, dynamic> oldRecord})
    >
    callback,
  }) {
    // Reactively watch the conversation's messages via PowerSync and emit
    // per-row deltas (insert/update/delete) to mirror the previous realtime
    // callback contract. The first (baseline) emission is skipped so existing
    // rows are not replayed as inserts.
    var initialized = false;
    var previous = <String, Map<String, dynamic>>{};
    const equality = MapEquality<String, dynamic>();
    return _powerSyncRepository
        .db()
        .watch(
          // Same hydration as [messagesOf], so a realtime insert/update carries
          // the sender's avatar/username and the shared-post media — a bare
          // `SELECT *` dropped all of those, making live bubbles look broken.
          // m_sender is LEFT joined so a message never disappears just because
          // the sender profile hasn't synced yet.
          '''
SELECT
  m.*,
  m_sender.full_name as full_name,
  m_sender.username as username,
  m_sender.avatar_url as avatar_url,
  a.id as attachment_id,
  a.title as attachment_title,
  a.text as attachment_text,
  a.title_link as attachment_title_link,
  a.image_url as attachment_image_url,
  a.thumb_url as attachment_thumb_url,
  a.author_name as attachment_author_name,
  a.author_link as attachment_author_link,
  a.asset_url as attachment_asset_url,
  a.og_scrape_url as attachment_og_scrape_url,
  a.type as attachment_type,
  r.message as replied_message_message,
  p.caption as shared_post_caption,
  p.created_at as shared_post_created_at,
  p.media as shared_post_media,
  p_author.id as shared_post_author_id,
  p_author.username as shared_post_author_username,
  p_author.full_name as shared_post_author_full_name,
  p_author.avatar_url as shared_post_author_avatar_url,
  st.content_url as shared_story_content_url,
  st.content_type as shared_story_content_type,
  st.created_at as shared_story_created_at,
  st.expires_at as shared_story_expires_at,
  st.duration as shared_story_duration,
  st_author.id as shared_story_author_id,
  st_author.username as shared_story_author_username,
  st_author.full_name as shared_story_author_full_name,
  st_author.avatar_url as shared_story_author_avatar_url
FROM
  messages m
  left join attachments a on m.id = a.message_id
  left join messages r on m.reply_message_id = r.id
  left join posts p on m.shared_post_id = p.id
  left join profiles m_sender on m.from_id = m_sender.id
  left join profiles p_author on p.user_id = p_author.id
  left join stories st on m.shared_story_id = st.id
  left join profiles st_author on st.user_id = st_author.id
WHERE m.conversation_id = ?
''',
          parameters: [conversationId],
        )
        .listen((results) {
          final current = <String, Map<String, dynamic>>{};
          for (final row in results) {
            final map = Map<String, dynamic>.from(row);
            current[map['id'].toString()] = map;
          }
          if (!initialized) {
            initialized = true;
            previous = current;
            return;
          }
          // Inserts and updates.
          for (final entry in current.entries) {
            final old = previous[entry.key];
            if (old == null) {
              callback(
                (newRecord: entry.value, oldRecord: <String, dynamic>{}),
              );
            } else if (!equality.equals(old, entry.value)) {
              callback((newRecord: entry.value, oldRecord: old));
            }
          }
          // Deletes.
          for (final entry in previous.entries) {
            if (!current.containsKey(entry.key)) {
              callback(
                (newRecord: <String, dynamic>{}, oldRecord: entry.value),
              );
            }
          }
          previous = current;
        });
  }

  @override
  String? get currentUserId => EntraSession.instance.current?.userId;

  @override
  Stream<User> profile({required String id}) => _powerSyncRepository
      .db()
      .watch(
        'SELECT * FROM profiles WHERE id = ?',
        parameters: [id],
      )
      .map(
        (event) => event.isEmpty ? User.anonymous : User.fromJson(event.first),
      );

  @override
  Future<void> updatePresence({required String userId}) async {
    // Local wall-clock, same basis as message timestamps, so a Dart-side
    // "now - last_seen" comparison is apples-to-apples. profiles UPDATEs sync
    // fine (unlike messages), so presence round-trips across devices.
    await _powerSyncRepository.db().execute(
      'UPDATE profiles SET last_seen_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), userId],
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
    final author = authorRow != null ? User.fromJson(authorRow) : User.anonymous;
    final jsonMedia = json['media'] as String;

    final rootToken = RootIsolateToken.instance!;
    final mediaResult = await compute(_computeJsonMedia, [
      rootToken,
      jsonMedia,
    ]);
    final postMedia = List<Media>.from(
      mediaResult.map(Media.fromJson).toList(),
    );
    return Post.fromJson(json, media: postMedia).copyWith(author: author);
  }

  @override
  Stream<Set<String>> visitedRegionsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
    SELECT DISTINCT location_region FROM posts
    WHERE user_id = ? AND location_region IS NOT NULL AND location_region != ''
    ''',
            parameters: [userId],
          )
          .map(
            (result) => result
                .map((row) => row['location_region'] as String)
                .toSet(),
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
    )
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
    WHERE user_id = ? AND location_lat IS NOT NULL AND location_lng IS NOT NULL
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
        '''
    SELECT location_lat, location_lng, location_name FROM stories
    WHERE user_id = ? AND location_lat IS NOT NULL AND location_lng IS NOT NULL
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
            for (final part
                in ((row['invite_dates'] as String?) ?? '').split(',')) {
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
            (event) => event
                .map((row) => row['region_iso'] as String)
                .toSet(),
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
WHERE h.user_id = ?
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
    final now = DateTime.now().toIso8601String();
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
      [uuid.v4(), highlightId, storyId, DateTime.now().toIso8601String()],
    );
  }

  @override
  Future<void> setStoryLocation({
    required String storyId,
    required double lat,
    required double lng,
    String? name,
  }) =>
      // Only lat/lng — deliberately NOT location_name: that column drives the
      // "place" chip under the author on the story, and pinning to the map must
      // not make that chip appear. The map pin only needs the coordinates.
      _powerSyncRepository.db().execute(
        'UPDATE stories SET location_lat = ?, location_lng = ? WHERE id = ?',
        [lat, lng, storyId],
      );

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
WHERE s.saver_id = ?
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
  }) =>
      _powerSyncRepository
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
      [uuid.v4(), userId, profileId, DateTime.now().toIso8601String()],
    );
  }

  @override
  Future<void> unsaveProfile({
    required String userId,
    required String profileId,
  }) =>
      _powerSyncRepository.db().execute(
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
          [uuid.v4(), userId, iso, DateTime.now().toIso8601String()],
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
       pr.username AS actor_username, pr.avatar_url AS actor_avatar,
       pr.full_name AS actor_name
FROM (
  SELECT 'like' AS type, l.user_id AS actor_id, l.post_id AS post_id,
         NULL AS content, l.created_at AS created_at
  FROM likes l
  JOIN posts p ON p.id = l.post_id
  WHERE p.user_id = ?1 AND l.user_id != ?1 AND l.post_id IS NOT NULL
  UNION ALL
  SELECT 'comment', c.user_id, c.post_id, c.content, c.created_at
  FROM comments c
  JOIN posts p ON p.id = c.post_id
  WHERE p.user_id = ?1 AND c.user_id != ?1
  UNION ALL
  -- A pending row is a follow REQUEST (Accept/Decline); an accepted row is a
  -- plain "started following you" notice.
  SELECT (CASE WHEN s.status = 'pending' THEN 'follow_request' ELSE 'follow' END),
         s.subscriber_id, NULL, NULL, s.created_at
  FROM subscriptions s
  WHERE s.subscribed_to_id = ?1 AND s.subscriber_id != ?1
) act
LEFT JOIN profiles pr ON pr.id = act.actor_id
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
  SELECT l.created_at AS created_at
  FROM likes l
  JOIN posts p ON p.id = l.post_id
  WHERE p.user_id = ?1 AND l.user_id != ?1 AND l.post_id IS NOT NULL
  UNION ALL
  SELECT c.created_at
  FROM comments c
  JOIN posts p ON p.id = c.post_id
  WHERE p.user_id = ?1 AND c.user_id != ?1
  UNION ALL
  SELECT s.created_at
  FROM subscriptions s
  WHERE s.subscribed_to_id = ?1 AND s.subscriber_id != ?1
) act
-- The watermark lives on the profile, so this join puts `profiles` in the
-- watched set too and the badge clears itself the moment it is bumped.
LEFT JOIN profiles me ON me.id = ?1
WHERE me.notifications_seen_at IS NULL
   OR act.created_at > me.notifications_seen_at
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
WHERE $where
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
    double radiusDegrees = 0.02,
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
    final rootToken = RootIsolateToken.instance!;
    final media = await compute<List<dynamic>, List<List<Map<String, dynamic>>>>(
      _computeJsonListMedia,
      [rootToken, jsonListMedia],
    );
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
  Stream<List<Post>> postsOf({String? userId}) {
    if (currentUserId == null) return const Stream.empty();
    assert(
      userId != null && currentUserId != null,
      'Both given `userId` and `currentUserId` cannot be null',
    );
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
WHERE user_id = ?
ORDER BY created_at DESC
      ''',
          parameters: [userId ?? currentUserId],
        )
        .asyncMap(
          (result) async {
            final jsonListMedia = result.map((row) {
              final json = Map<String, dynamic>.from(row);
              return json['media'] as String;
            }).toList();

            final rootToken = RootIsolateToken.instance!;
            final media =
                await compute<List<dynamic>, List<List<Map<String, dynamic>>>>(
                  _computeJsonListMedia,
                  [rootToken, jsonListMedia],
                );

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

  static List<List<Map<String, dynamic>>> _computeJsonListMedia(
    List<dynamic> args,
  ) {
    final rootToken = args[0] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    final jsonListMedia = args[1] as List<String?>;
    final listMedia = jsonListMedia
        .map(
          (jsonMedia) =>
              (jsonMedia == null
                      ? <Map<String, dynamic>>[]
                      : jsonDecode(jsonMedia) as List<dynamic>)
                  .cast<Map<String, dynamic>>(),
        )
        .toList();

    return listMedia;
  }

  static List<Map<String, dynamic>> _computeJsonMedia(
    List<dynamic> args,
  ) {
    final rootToken = args[0] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);
    final jsonMedia = args[1] as String;
    final listMedia = (jsonDecode(jsonMedia) as List<dynamic>)
        .cast<Map<String, dynamic>>();

    return listMedia;
  }

  @override
  Future<List<Post>> getPage({
    required int offset,
    required int limit,
    bool onlyReels = false,
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
ORDER BY created_at DESC LIMIT ?1 OFFSET ?2
    ''',
      [limit, offset],
    );
    final jsonListMedia = result.map((row) {
      final json = Map<String, dynamic>.from(row);
      return json['media'] as String;
    }).toList();

    final rootToken = RootIsolateToken.instance!;
    final media = await compute(
      _computeJsonListMedia,
      [rootToken, jsonListMedia],
    );

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
    final jsonMedia = json['media'] as String;

    final rootToken = RootIsolateToken.instance!;
    final result = await compute(_computeJsonMedia, [rootToken, jsonMedia]);
    final media = List<Media>.from(result.map(Media.fromJson).toList());
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
WHERE posts.id = ?
  ''',
      [id],
    );
    if (row == null) return null;
    final json = Map<String, dynamic>.from(row);
    final jsonMedia = json['media'] as String;

    final rootToken = RootIsolateToken.instance!;
    final mediaResult = await compute(_computeJsonMedia, [
      rootToken,
      jsonMedia,
    ]);
    final postMedia = List<Media>.from(
      mediaResult.map(Media.fromJson).toList(),
    );
    return Post.fromJson(json, media: postMedia);
  }

  @override
  Future<void> like({
    required String id,
    bool post = true,
  }) async {
    if (currentUserId == null) return;
    final statement = post ? 'post_id' : 'comment_id';
    final exists = await _powerSyncRepository.db().execute(
      'SELECT 1 FROM likes '
      'WHERE user_id = ? AND $statement = ? AND $statement IS NOT NULL',
      [currentUserId, id],
    );
    if (exists.isEmpty) {
      await _powerSyncRepository.db().execute(
        '''
          INSERT INTO likes(user_id, $statement, id)
            VALUES(?, ?, uuid())
      ''',
        [currentUserId, id],
      );
      return;
    }
    await _powerSyncRepository.db().execute(
      '''
          DELETE FROM likes
          WHERE user_id = ? AND $statement = ? AND $statement IS NOT NULL
      ''',
      [currentUserId, id],
    );
  }

  @override
  Future<void> bookmarkPost({required String postId}) async {
    if (currentUserId == null) return;
    final exists = await _powerSyncRepository.db().execute(
      'SELECT 1 FROM saved_posts WHERE user_id = ? AND post_id = ?',
      [currentUserId, postId],
    );
    if (exists.isEmpty) {
      await _powerSyncRepository.db().execute(
        '''
          INSERT INTO saved_posts(id, user_id, post_id, created_at)
            VALUES(uuid(), ?, ?, ?)
      ''',
        [currentUserId, postId, DateTime.now().toIso8601String()],
      );
      return;
    }
    await _powerSyncRepository.db().execute(
      'DELETE FROM saved_posts WHERE user_id = ? AND post_id = ?',
      [currentUserId, postId],
    );
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
WHERE saved_posts.user_id = ?1
ORDER BY saved_posts.created_at DESC LIMIT ?2 OFFSET ?3
    ''',
      [currentUserId, limit, offset],
    );
    final jsonListMedia = result.map((row) {
      final json = Map<String, dynamic>.from(row);
      return json['media'] as String;
    }).toList();

    final rootToken = RootIsolateToken.instance!;
    final media = await compute(
      _computeJsonListMedia,
      [rootToken, jsonListMedia],
    );

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
        [currentUserId, postId, DateTime.now().toIso8601String()],
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

    final rootToken = RootIsolateToken.instance!;
    final media = await compute(
      _computeJsonListMedia,
      [rootToken, jsonListMedia],
    );

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
        'WHERE subscribed_to_id = ?',
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
    if (currentUserId == null) return;
    if (followToId == currentUserId) return;
    final exists = await isFollowed(
      followerId: followerId ?? currentUserId!,
      userId: followToId,
    );
    if (!exists) {
      // A private account is followed by REQUEST: the row lands as 'pending'
      // and only unlocks content once the owner accepts it. A public account
      // is followed outright ('accepted'), exactly as before.
      final targetPrivate = await _isPrivateProfile(followToId);
      await _powerSyncRepository.db().execute(
        '''
          INSERT INTO subscriptions(id, subscriber_id, subscribed_to_id, status)
            VALUES(uuid(), ?, ?, ?)
      ''',
        [
          followerId ?? currentUserId!,
          followToId,
          targetPrivate ? 'pending' : 'accepted',
        ],
      );
      return;
    }
    // Already following OR a request is pending — tapping again cancels either
    // (a plain delete works for both, so a pending request is withdrawn).
    await unfollow(
      unfollowId: followToId,
      unfollowerId: followerId ?? currentUserId!,
    );
  }

  /// Whether [userId]'s profile is private, read from the local mirror.
  Future<bool> _isPrivateProfile(String userId) async {
    final row = await _powerSyncRepository.db().getOptional(
      'SELECT is_private FROM profiles WHERE id = ?',
      [userId],
    );
    final value = row?['is_private'];
    return value == 1 || value == true;
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
  Stream<int> followingsCountOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            'SELECT COUNT(*) AS subscription_count FROM subscriptions '
            'WHERE subscriber_id = ?',
            parameters: [userId],
          )
          .map(
            (event) =>
                event.safeMap((element) => element['subscription_count']).first
                    as int,
          );

  @override
  Future<List<User>> getFollowers({String? userId}) async {
    final followersId = await _powerSyncRepository.db().getAll(
      'SELECT subscriber_id FROM subscriptions WHERE subscribed_to_id = ? ',
      [userId ?? currentUserId],
    );
    if (followersId.isEmpty) return [];

    final followers = <User>[];
    for (final followerId in followersId) {
      final result = await _powerSyncRepository.db().execute(
        'SELECT * FROM profiles WHERE id = ?',
        [followerId['subscriber_id']],
      );
      if (result.isEmpty) continue;
      final follower = User.fromJson(result.first);
      followers.add(follower);
    }
    return followers;
  }

  @override
  Stream<List<User>> followers({required String userId}) async* {
    final streamResult = _powerSyncRepository.db().watch(
      'SELECT subscriber_id FROM subscriptions WHERE subscribed_to_id = ? ',
      parameters: [userId],
    );
    await for (final result in streamResult) {
      final followers = <User>[];
      final followersFutures = await Future.wait(
        result
            .where((row) => row.isNotEmpty)
            .safeMap(
              (row) => _powerSyncRepository.db().getOptional(
                'SELECT * FROM profiles WHERE id = ?',
                [row['subscriber_id']],
              ),
            ),
      );
      for (final user in followersFutures) {
        if (user == null) continue;
        final follower = User.fromJson(user);
        followers.add(follower);
      }
      yield followers;
    }
  }

  @override
  Future<List<User>> getFollowings({String? userId}) async {
    final followingsUserId = await _powerSyncRepository.db().getAll(
      'SELECT subscribed_to_id FROM subscriptions WHERE subscriber_id = ? ',
      [userId ?? currentUserId],
    );
    if (followingsUserId.isEmpty) return [];

    final followings = <User>[];
    for (final followingsUserId in followingsUserId) {
      final result = await _powerSyncRepository.db().execute(
        'SELECT * FROM profiles WHERE id = ?',
        [followingsUserId['subscribed_to_id']],
      );
      if (result.isEmpty) continue;
      final following = User.fromJson(result.first);
      followings.add(following);
    }
    return followings;
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
WHERE post_id = ? 
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
WHERE
  c1.post_id = ? AND c1.replied_to_comment_id IS NULL
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
  Future<void> sharePost({
    required String id,
    required User sender,
    required User receiver,
    required Message sharedPostMessage,
    Message? message,
    PostAuthor? postAuthor,
  }) async {
    final exists = await _powerSyncRepository.db().execute(
      '''
SELECT 1 FROM posts WHERE id = ?
''',
      [id],
    );
    if (exists.isEmpty) return;
    final conversation = await _powerSyncRepository.db().execute(
      '''
SELECT conversation_id
  FROM participants
WHERE user_id = ?
  AND conversation_id IN (
      SELECT conversation_id
      FROM participants
      WHERE user_id = ?
    );
''',
      [sender.id, receiver.id],
    );
    if (conversation.isNotEmpty) {
      final chatId = conversation.first['conversation_id'] as String;
      await Future.wait([
        sendMessage(
          chatId: chatId,
          sender: sender,
          receiver: receiver,
          message: sharedPostMessage,
          postAuthor: postAuthor,
        ),
        if (message != null)
          sendMessage(
            chatId: chatId,
            sender: sender,
            receiver: receiver,
            message: message,
          ),
      ]);
      return;
    }
    final newChatId = uuid.v4();
    final createdConversation = _powerSyncRepository.db().execute(
      '''
insert into
  conversations (id, type, name, created_at, updated_at)
values
  (?, ?, '', ?, ?)
''',
      [newChatId, ChatType.oneOnOne.value, JiffyX.now(), JiffyX.now()],
    );
    final addParticipant1 = _powerSyncRepository.db().execute(
      '''
insert into
  participants (id, user_id, conversation_id)
  values
  (?, ?, ?)
  ''',
      [uuid.v4(), sender.id, newChatId],
    );
    final addParticipant2 = _powerSyncRepository.db().execute(
      '''
insert into
  participants (id, user_id, conversation_id)
  values
  (?, ?, ?)
  ''',
      [uuid.v4(), receiver.id, newChatId],
    );
    await createdConversation.whenComplete(
      () => Future.wait([addParticipant1, addParticipant2]),
    );

    await Future.wait([
      sendMessage(
        chatId: newChatId,
        sender: sender,
        receiver: receiver,
        message: sharedPostMessage,
        postAuthor: postAuthor,
      ),
      if (message != null)
        sendMessage(
          chatId: newChatId,
          sender: sender,
          receiver: receiver,
          message: message,
        ),
    ]);
  }

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
  c1.replied_to_comment_id = ? 
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
    if (exists != null) return;
    await _powerSyncRepository.db().execute(
      '''
INSERT INTO blocked_users(id, blocker_id, blocked_id, created_at)
VALUES(?, ?, ?, ?)''',
      [uuid.v4(), userId, blockedId, JiffyX.now()],
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
  Stream<List<ChatInbox>> chatsOf({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
select
  c.id,
  c.type,
  c.name,
  p2.id as participant_id,
  p2.full_name as participant_name,
  p2.email as participant_email,
  p2.username as participant_username,
  p2.avatar_url as participant_avatar_url,
  p2.push_token as participant_push_token,
  (
    select lm.message
    from messages lm
    where lm.conversation_id = c.id
    order by lm.created_at desc
    limit 1
  ) as last_message,
  (
    select lm.created_at
    from messages lm
    where lm.conversation_id = c.id
    order by lm.created_at desc
    limit 1
  ) as last_message_at,
  (
    select count(*)
    from messages um
    where um.conversation_id = c.id
      and um.from_id != ?1
      and (um.is_deleted is null or um.is_deleted = 0)
      -- Unread = arrived after this device last opened the chat. julianday()
      -- normalizes the timestamp so the 'T' vs space / 'Z' format difference
      -- between message and watermark strings can't skew the comparison.
      and julianday(um.created_at) > julianday(
        coalesce(
          (select clr.last_read_at from chat_last_read clr where clr.id = c.id),
          '1970-01-01'
        )
      )
  ) as unread_messages_count
from
  conversations c
  join participants pt on c.id = pt.conversation_id
  join profiles p on pt.user_id = p.id
  join participants pt2 on c.id = pt2.conversation_id
  join profiles p2 on pt2.user_id = p2.id
where
  pt.user_id = ?1
  and pt2.user_id != ?1
-- One row per other person, not per conversation. Duplicate 1-on-1
-- conversations exist because they were created while chat sync was broken
-- (the "already exists?" check queried a local db that had no conversations,
-- so every tap made a new one). Collapse them to the most recent; SQLite's
-- bare-column rule returns the row matching max(updated_at).
group by p2.id
having c.updated_at = max(c.updated_at)
-- Most recently active chat first. NULL (never-messaged) sorts last in DESC.
order by last_message_at desc
''',
            parameters: [userId],
          )
          .map(
            (event) => event.safeMap(ChatInbox.fromRow).toList(growable: false),
          );

  @override
  Stream<int> unreadMessagesCount({required String userId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT COUNT(*) AS c
FROM messages m
JOIN participants pt ON pt.conversation_id = m.conversation_id
WHERE pt.user_id = ?1
  AND m.from_id != ?1
  AND (m.is_deleted IS NULL OR m.is_deleted = 0)
  -- Same device-local watermark as the per-chat badge (is_read doesn't sync).
  AND julianday(m.created_at) > julianday(coalesce(
    (select clr.last_read_at from chat_last_read clr where clr.id = m.conversation_id),
    '1970-01-01'
  ))
''',
            parameters: [userId],
          )
          .map((rows) => (rows.first['c'] as int?) ?? 0);

  @override
  Stream<List<Message>> messagesOf({required String chatId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT
  m.*,
  m_sender.full_name as full_name,
  m_sender.username as username,
  m_sender.avatar_url as avatar_url,
  a.id as attachment_id,
  a.title as attachment_title,
  a.text as attachment_text,
  a.title_link as attachment_title_link,
  a.image_url as attachment_image_url,
  a.thumb_url as attachment_thumb_url,
  a.author_name as attachment_author_name,
  a.author_link as attachment_author_link,
  a.asset_url as attachment_asset_url,
  a.og_scrape_url as attachment_og_scrape_url,
  a.type as attachment_type,
  r.message as replied_message_message,
  p.caption as shared_post_caption,
  p.created_at as shared_post_created_at,
  p.media as shared_post_media,
  p_author.id as shared_post_author_id,
  p_author.username as shared_post_author_username,
  p_author.full_name as shared_post_author_full_name,
  p_author.avatar_url as shared_post_author_avatar_url,
  st.content_url as shared_story_content_url,
  st.content_type as shared_story_content_type,
  st.created_at as shared_story_created_at,
  st.expires_at as shared_story_expires_at,
  st.duration as shared_story_duration,
  st_author.id as shared_story_author_id,
  st_author.username as shared_story_author_username,
  st_author.full_name as shared_story_author_full_name,
  st_author.avatar_url as shared_story_author_avatar_url
FROm
  messages m
  left join attachments a on m.id = a.message_id
  left join messages r on m.reply_message_id = r.id
  left join posts p on m.shared_post_id = p.id
  join profiles m_sender on m.from_id = m_sender.id
  left join profiles p_author on p.user_id = p_author.id
  left join stories st on m.shared_story_id = st.id
  left join profiles st_author on st.user_id = st_author.id
where
  m.conversation_id = ?   
order by created_at asc
''',
            parameters: [chatId],
          )
          .asyncMap(
            (result) async {
              final messages = <Message>[];
              if (result.isEmpty) return messages;
              final listMediaJson = result
                  .map((e) => e['shared_post_media'] as String?)
                  .toList();
              final resultMedia = await compute(
                _computeJsonListMedia,
                [RootIsolateToken.instance!, listMediaJson],
              );
              for (var i = 0; i < result.length; i++) {
                final json = Map<String, dynamic>.from(result[i]);
                final indexedMedia = resultMedia[i];
                Message message;
                if (indexedMedia.isEmpty) {
                  message = Message.fromRow(json);
                } else {
                  final media = indexedMedia.map(Media.fromJson).toList();
                  message = Message.fromRow(json, media: media);
                }
                messages.add(message);
              }
              return messages;
            },
          );

  @override
  Future<String> createChat({
    required String userId,
    required String participantId,
  }) async {
    final alreadyExists = await _powerSyncRepository.db().getOptional(
      '''
      SELECT c.id AS id
      FROM conversations c
      JOIN participants p1 ON c.id = p1.conversation_id
      JOIN participants p2 ON c.id = p2.conversation_id
      WHERE p1.user_id = ? AND p2.user_id = ?
  ''',
      [userId, participantId],
    );
    if (alreadyExists != null) return alreadyExists['id'] as String;
    final conversationId = uuid.v4();
    // Insert the conversation FIRST, then its participants. Previously the
    // participant inserts were eager futures that could land before the
    // conversation row (it only worked because the local db doesn't enforce
    // FKs); ordering them keeps the write consistent.
    await _powerSyncRepository.db().execute(
      '''
insert into
  conversations (id, type, name, created_at, updated_at)
values
  (?, ?, '', ?, ?)
''',
      [conversationId, ChatType.oneOnOne.value, JiffyX.now(), JiffyX.now()],
    );
    await Future.wait([
      _powerSyncRepository.db().execute(
        'insert into participants (id, user_id, conversation_id) '
        'values (?, ?, ?)',
        [uuid.v4(), userId, conversationId],
      ),
      _powerSyncRepository.db().execute(
        'insert into participants (id, user_id, conversation_id) '
        'values (?, ?, ?)',
        [uuid.v4(), participantId, conversationId],
      ),
    ]);
    return conversationId;
  }

  @override
  Future<void> deleteChat({
    required String chatId,
    required String userId,
  }) async {
    //     final participants = (await _powerSyncRepository.db().get(
    //       '''
    // select
    //   count(*) as participants_count
    // from
    //   participants
    // where conversation_id = ?
    // ''',
    //       [chatId],
    //     ))['participants_count'] as int;
    //     if (participants >= 1) {
    //       final isParticipantInConversation = await _powerSyncRepository.db()
    // .get(
    //         '''
    // select
    //   *
    // from
    //   participants
    // where
    //   user_id = ?
    //   and conversation_id = ?
    //   ''',
    //         [userId, chatId],
    //       );
    //       if (isParticipantInConversation.isEmpty) return;
    //       await _powerSyncRepository.db().execute(
    //         '''
    // delete from participants
    // where
    //   user_id = ?
    //   and conversation_id = ?
    // ''',
    //         [userId, chatId],
    //       );
    //       return;
    //     }
    await _powerSyncRepository.db().execute(
      '''
delete from conversations
where
  id = ?
''',
      [chatId],
    );
  }

  @override
  Future<void> deleteMessage({required String messageId}) =>
      _powerSyncRepository.db().execute(
        '''
delete from messages
where
  id = ?
''',
        [messageId],
      );

  @override
  Future<void> readMessage({
    required String messageId,
  }) async {
    await _powerSyncRepository.db().execute(
      '''
UPDATE messages
SET
  is_read = 1
WHERE
  id = ?
''',
      [messageId],
    );
  }

  @override
  Future<void> markConversationRead({
    required String chatId,
    required String userId,
  }) async {
    // Record "opened just now" in a device-local table. We deliberately do NOT
    // touch messages.is_read: that update doesn't round-trip through PowerSync
    // (it reverts locally), which left the unread badge stuck. The local
    // watermark is never synced or reverted, so the badge clears reliably.
    final now = DateTime.now().toIso8601String();
    await _powerSyncRepository.db().execute(
      'INSERT OR REPLACE INTO chat_last_read(id, last_read_at) VALUES(?, ?)',
      // Same basis as messages.created_at (sendMessage writes a naive local
      // wall-clock via DateTime.now().toIso8601String()). Using toUtc() here
      // instead skewed the comparison by the timezone offset, so the badge
      // never cleared.
      [chatId, now],
    );
    // Also a SYNCED watermark, so the other person's messages can show ✓✓.
    await _powerSyncRepository.db().execute(
      'INSERT OR REPLACE INTO conversation_reads'
      '(id, conversation_id, user_id, last_read_at) VALUES(?, ?, ?, ?)',
      ['${chatId}_$userId', chatId, userId, now],
    );
  }

  @override
  Stream<DateTime?> otherReadAtOf({
    required String conversationId,
    required String excludeUserId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT last_read_at FROM conversation_reads '
        'WHERE conversation_id = ? AND user_id != ? '
        'ORDER BY last_read_at DESC LIMIT 1',
        parameters: [conversationId, excludeUserId],
      )
      .map((rows) {
        if (rows.isEmpty) return null;
        final raw = rows.first['last_read_at'] as String?;
        return raw == null ? null : DateTime.tryParse(raw);
      });

  @override
  Future<void> setTyping({
    required String conversationId,
    required String userId,
  }) async {
    // One row per (conversation, user); INSERT OR REPLACE (a PowerSync PUT,
    // which uploads like an insert) keeps it single and bumps the timestamp.
    await _powerSyncRepository.db().execute(
      'INSERT OR REPLACE INTO typing_status'
      '(id, conversation_id, user_id, updated_at) VALUES(?, ?, ?, ?)',
      [
        '${conversationId}_$userId',
        conversationId,
        userId,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  @override
  Stream<DateTime?> typingUpdatedAtOf({
    required String conversationId,
    required String excludeUserId,
  }) => _powerSyncRepository
      .db()
      .watch(
        'SELECT updated_at FROM typing_status '
        'WHERE conversation_id = ? AND user_id != ? '
        'ORDER BY updated_at DESC LIMIT 1',
        parameters: [conversationId, excludeUserId],
      )
      .map((rows) {
        if (rows.isEmpty) return null;
        final raw = rows.first['updated_at'] as String?;
        return raw == null ? null : DateTime.tryParse(raw);
      });

  @override
  Future<void> sendMessage({
    required String chatId,
    required User sender,
    required User receiver,
    required Message message,
    PostAuthor? postAuthor,
  }) => _powerSyncRepository.db().writeTransaction((sqlContext) async {
    await sqlContext.execute(
      '''
insert into
  messages (
    id, conversation_id, from_id, type, message, reply_message_id, created_at, 
    updated_at, is_read, is_deleted, is_edited, reply_message_username,
    reply_message_attachment_url, shared_post_id, shared_story_id,
    reply_message_message, from_username
    )
values
  (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?, ?)
''',
      [
        message.id,
        chatId,
        sender.id,
        message.type.value,
        message.message,
        message.replyMessageId,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
        message.replyMessageUsername,
        message.replyMessageAttachmentUrl,
        message.sharedPostId,
        message.sharedStoryId,
        message.replyMessageMessage,
        sender.username,
      ],
    );

    if (message.attachments.isNotEmpty) {
      await sqlContext.executeBatch(
        '''
insert into
  attachments (
    id, message_id, title, text, title_link, image_url,
    thumb_url, author_name, author_link, asset_url, og_scrape_url, type
  )
values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        message.attachments
            .map(
              (a) => [
                a.id,
                message.id,
                a.title,
                a.text,
                a.titleLink,
                a.imageUrl,
                a.thumbUrl,
                a.authorName,
                a.authorLink,
                a.assetUrl,
                a.ogScrapeUrl,
                a.type,
              ],
            )
            .toList(),
      );
    }

    // No push notification goes out here. The Supabase Edge Function that used
    // to send them died with Supabase, and Firebase is gone from the app, so a
    // closed app cannot be reached at all — in-app notifications still work,
    // they are read from the database.
  });

  @override
  Future<void> editMessage({
    required Message oldMessage,
    required Message newMessage,
  }) async {
    late final newMessageHasAttachments = newMessage.attachments.isNotEmpty;
    late final oldMessageHasAttachments = oldMessage.attachments.isNotEmpty;
    late final updateOldMessageAttachments =
        newMessageHasAttachments && oldMessageHasAttachments;
    late final insertNewMessageAttachments =
        newMessageHasAttachments && !oldMessageHasAttachments;

    await _powerSyncRepository.db().execute(
      '''
update messages
set
  message = ?1,
  updated_at = ?2,
  is_edited = 1
where
  id = ?3
''',
      [
        newMessage.message,
        DateTime.timestamp().toIso8601String(),
        newMessage.id,
      ],
    );
    if (!newMessageHasAttachments && oldMessageHasAttachments) {
      await _powerSyncRepository.db().execute(
        '''
delete from attachments
where message_id = ?
        ''',
        [newMessage.id],
      );
      return;
    }
    if (updateOldMessageAttachments) {
      final oldAttachmentId = oldMessage.attachments.first.id;
      await _powerSyncRepository.db().executeBatch(
        '''
update attachments
set
  title = ?,
  text = ?,
  title_link = ?,
  image_url = ?,
  thumb_url = ?,
  author_name = ?,
  author_link = ?,
  asset_url = ?,
  og_scrape_url = ?
where
  id = ?
  and message_id = ?
''',
        newMessage.attachments
            .map(
              (a) => [
                a.title,
                a.text,
                a.titleLink,
                a.imageUrl,
                a.thumbUrl,
                a.authorName,
                a.authorLink,
                a.assetUrl,
                a.ogScrapeUrl,
                oldAttachmentId,
                oldMessage.id,
              ],
            )
            .toList(),
      );
      return;
    }
    if (insertNewMessageAttachments) {
      await _powerSyncRepository.db().executeBatch(
        '''
insert into
  attachments (
    id, message_id, title, text, title_link, image_url,
    thumb_url, author_name, author_link, asset_url, og_scrape_url, type
  )
values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
        newMessage.attachments
            .map(
              (a) => [
                a.id,
                newMessage.id,
                a.title,
                a.text,
                a.titleLink,
                a.imageUrl,
                a.thumbUrl,
                a.authorName,
                a.authorLink,
                a.assetUrl,
                a.ogScrapeUrl,
                a.type,
              ],
            )
            .toList(),
      );
    }
  }

  @override
  Future<List<User>> searchUsers({
    required int limit,
    required int offset,
    required String? query,
    String? userId,
    String? excludeUserIds,
  }) async {
    if (query == null || query.trim().isEmpty) return <User>[];
    // Keep dots, dashes and underscores — they are legal in a handle, and
    // stripping them turned "h.hamid15" into "hhamid15", which matches nobody.
    query = query.removeSpecialCharacters(keepAllowed: true);
    final excludeUserIdsStatement = excludeUserIds == null
        ? ''
        : 'AND id NOT IN ($excludeUserIds)';

    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT id, avatar_url, full_name, username
  FROM profiles
WHERE (LOWER(username) LIKE LOWER('%$query%') OR LOWER(full_name) LIKE LOWER('%$query%'))
  AND id <> ?1 $excludeUserIdsStatement 
LIMIT ?2 OFFSET ?3
''',
      [currentUserId, limit, offset],
    );

    return result.safeMap(User.fromJson).toList(growable: false);
  }

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
      [uuid.v4(), storyId, viewerId, DateTime.now().toIso8601String()],
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
  Stream<List<User>> storyViewersOf({required String storyId}) =>
      _powerSyncRepository
          .db()
          .watch(
            '''
SELECT p.* FROM story_views sv
  JOIN profiles p ON p.id = sv.user_id
WHERE sv.story_id = ?
ORDER BY sv.created_at DESC
''',
            parameters: [storyId],
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
      [uuid.v4(), storyId, userId, DateTime.now().toIso8601String()],
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
WHERE user_id = ? AND expires_at > current_timestamp
ORDER BY s.created_at ASC
''',
        parameters: [userId],
      )
      .map((event) => event.safeMap(Story.fromJson).toList(growable: false));

  @override
  Future<Story?> getStoryBy({required String id}) async {
    final row = await _powerSyncRepository.db().getOptional(
      '''
SELECT s.*, p.id as user_id, p.username, p.full_name, p.avatar_url
FROM stories s
  LEFT JOIN profiles p ON s.user_id = p.id
WHERE s.id = ?
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
    double radiusDegrees = 0.02,
  }) {
    // A pin and a whole region are the same table, told apart by whether the
    // row carries coordinates — so the point view never picks up region pins
    // sitting at some unrelated spot.
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
      [userId, storyId, regionIso, lat, lng, DateTime.now().toIso8601String()],
    );
  }

  @override
  Future<void> unpinStoryFromLocation({
    required String userId,
    required String storyId,
    required String regionIso,
    double? lat,
    double? lng,
  }) => _powerSyncRepository.db().execute(
    '''
DELETE FROM location_stories
WHERE user_id = ?1 AND story_id = ?2 AND region_iso = ?3
  AND ((lat IS NULL AND ?4 IS NULL) OR lat = ?4)
  AND ((lng IS NULL AND ?5 IS NULL) OR lng = ?5)
''',
    [userId, storyId, regionIso, lat, lng],
  );

  @override
  Future<String> uploadStoryMedia({
    required String storyId,
    required File imageFile,
    required Uint8List imageBytes,
  }) async {
    final stories = MediaStorage.instance.from('stories');
    final imageExtension = imageFile.path.split('.').last.toLowerCase();
    final imagePath = '$storyId/image';

    await stories.uploadBinary(
      imagePath,
      imageBytes,
      fileOptions: MediaFileOptions(
        contentType: 'image/$imageExtension',
        cacheControl: '9000000',
      ),
    );
    return stories.getPublicUrl(imagePath);
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
INNER JOIN posts p ON l.post_id = p.id
WHERE p.post_id ?
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
    ) AND id <> ?2
)
LIMIT ?3 OFFSET ?4
''',
      [postId, currentUserId, limit, offset],
    );
    if (result.isEmpty) return [];
    return result.safeMap(User.fromJson).toList(growable: false);
  }

  @override
  Future<List<Message>> getMessages({
    required String chatId,
    required int limit,
    required int offset,
  }) async {
    final result = await _powerSyncRepository.db().getAll(
      '''
SELECT
  m.*,
  m_sender.full_name as full_name,
  m_sender.username as username,
  m_sender.avatar_url as avatar_url,
  a.id as attachment_id,
  a.title as attachment_title,
  a.text as attachment_text,
  a.title_link as attachment_title_link,
  a.image_url as attachment_image_url,
  a.thumb_url as attachment_thumb_url,
  a.author_name as attachment_author_name,
  a.author_link as attachment_author_link,
  a.asset_url as attachment_asset_url,
  a.og_scrape_url as attachment_og_scrape_url,
  a.type as attachment_type,
  p.caption as shared_post_caption,
  p.created_at as shared_post_created_at,
  p.media as shared_post_media,
  p_author.id as shared_post_author_id,
  p_author.username as shared_post_author_username,
  p_author.full_name as shared_post_author_full_name,
  p_author.avatar_url as shared_post_author_avatar_url,
  st.content_url as shared_story_content_url,
  st.content_type as shared_story_content_type,
  st.created_at as shared_story_created_at,
  st.expires_at as shared_story_expires_at,
  st.duration as shared_story_duration,
  st_author.id as shared_story_author_id,
  st_author.username as shared_story_author_username,
  st_author.full_name as shared_story_author_full_name,
  st_author.avatar_url as shared_story_author_avatar_url
FROM
  messages m
  left join attachments a on m.id = a.message_id
  left join posts p on m.shared_post_id = p.id
  join profiles m_sender on m.from_id = m_sender.id
  left join profiles p_author on p.user_id = p_author.id
  left join stories st on m.shared_story_id = st.id
  left join profiles st_author on st.user_id = st_author.id
WHERE m.conversation_id = ?1   
ORDER BY created_at DESC
LIMIT ?2 OFFSET ?3
''',
      [chatId, limit, offset],
    );
    final messages = <Message>[];
    if (result.isEmpty) return messages;
    final listMediaJson = result
        .map((e) => e['shared_post_media'] as String?)
        .toList();
    if (listMediaJson.isEmpty ||
        !listMediaJson.any((element) => element != null)) {
      return result.safeMap(Message.fromRow).toList(growable: false);
    }
    final resultMedia = await compute(
      _computeJsonListMedia,
      [RootIsolateToken.instance!, listMediaJson],
    );
    for (var i = 0; i < result.length; i++) {
      final json = Map<String, dynamic>.from(result[i]);
      final indexedMedia = resultMedia[i];

      Message message;
      if (indexedMedia == <Map<String, dynamic>>[]) {
        message = Message.fromRow(json);
      } else {
        final media = indexedMedia.map(Media.fromJson).toList();
        message = Message.fromRow(json, media: media);
      }
      messages.add(message);
    }
    return messages;
  }

  @override
  Future<Message?> getRepliedMessage({required String messageId}) async {
    final result = await _powerSyncRepository.db().getOptional(
      '''
SELECT message from messages
WHERE id = ?
''',
      [messageId],
    );
    if (result == null) return null;
    return Message(message: result['message'] as String);
  }
}

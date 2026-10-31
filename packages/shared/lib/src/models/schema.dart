import 'package:powersync/powersync.dart';

/// The local database. What fills it is oci-backend/powersync/sync-config.yaml:
/// the user's own rows, everything of the people they follow, and the profile
/// or post open on screen — not every user's, as it used to be.
const schema = Schema([
  Table(
    'profiles',
    [
      Column.text('full_name'),
      Column.text('email'),
      Column.text('username'),
      Column.text('avatar_url'),
      Column.text('push_token'),
      // The invite badge. `referrals` only syncs to the person who owns them,
      // so a device cannot compute anyone else's tier — the server publishes it
      // here, on the profile, instead.
      Column.integer('referral_tier'),
      Column.text('referral_tier_expires_at'),
      Column.text('bio'),
      Column.integer('is_private'),
      Column.text('birthday'),
      Column.text('telegram'),
      Column.text('website'),
      Column.text('instagram'),
      Column.text('gender'),
      Column.text('onboarded_at'),
      // Watermark for the notification badge. Notifications are synthesised
      // from likes/comments/subscriptions and carry no per-row read flag, so
      // "unread" means "created after this timestamp". Kept on the profile so
      // the count clears across devices, the way the chat badge does.
      Column.text('notifications_seen_at'),
      // Presence: the app bumps this while foregrounded; the chat header shows
      // "online" when it is recent, else "last seen …".
      Column.text('last_seen_at'),
      // App language ('en' / 'ru') the server words push notifications in.
      // Written by the app; not synced back down.
      Column.text('lang'),
    ],
  ),
  // The signed-in user's own private profile fields. Since 2026-10-31 the
  // public `profiles` sync no longer carries email, birthday, gender, push
  // token or last-seen (they synced to every phone); the server sends them
  // only to their owner, as this table (sync rule `user_own_profile`). `id` is
  // the profile id. Writes still go to `profiles`.
  Table('my_profile', [
    Column.text('email'),
    Column.text('birthday'),
    Column.text('gender'),
    Column.text('push_token'),
    Column.text('last_seen_at'),
  ]),
  Table(
    'referrals',
    [
      Column.text('referrer_id'),
      Column.text('invited_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('referrer', [IndexedColumn('referrer_id')]),
    ],
  ),
  Table(
    'blocked_users',
    [
      Column.text('blocker_id'),
      Column.text('blocked_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('blocker', [IndexedColumn('blocker_id')]),
      // The blocked-either-way check runs inside most queries.
      Index('blocked', [IndexedColumn('blocked_id')]),
    ],
  ),
  Table(
    'posts',
    [
      Column.text('user_id'),
      Column.text('created_at'),
      Column.text('caption'),
      Column.text('updated_at'),
      Column.text('media'),
      Column.text('location'),
      Column.text('location_country'),
      Column.text('location_region'),
      Column.text('location_name'),
      Column.real('location_lat'),
      Column.real('location_lng'),
    ],
    indexes: [
      // A profile's grid, newest first, read straight off the index (no
      // sort); also serves every other lookup by author.
      Index('user', [IndexedColumn('user_id'), IndexedColumn('created_at')]),
      // The feed pages newest first.
      Index('created', [IndexedColumn('created_at')]),
    ],
  ),
  // A post's likes and comments, counted by the server: the phone no longer
  // has everyone's likes and comments to count. `id` is the post id.
  Table('post_stats', [
    Column.text('user_id'),
    Column.integer('likes_count'),
    Column.integer('comments_count'),
  ]),
  // A profile's counts, kept by the server. `id` is the profile id;
  // `places_count` is how many of their posts have a location.
  Table('profile_stats', [
    Column.integer('posts_count'),
    Column.integer('places_count'),
    Column.integer('followers_count'),
    Column.integer('following_count'),
  ]),
  // Likes and comments on the user's posts, follows and follow requests, with
  // who did it and the post's picture — kept by the server (the newest 300).
  // `source_id` is the like, comment or follow it is about.
  Table(
    'notifications',
    [
      Column.text('recipient_id'),
      Column.text('actor_id'),
      Column.text('type'),
      Column.text('source_id'),
      Column.text('post_id'),
      Column.text('content'),
      Column.text('post_thumb'),
      Column.text('actor_username'),
      Column.text('actor_full_name'),
      Column.text('actor_avatar_url'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('recipient', [
        IndexedColumn('recipient_id'),
        IndexedColumn('created_at'),
      ]),
    ],
  ),
  Table(
    'likes',
    [
      Column.text('user_id'),
      Column.text('comment_id'),
      Column.text('post_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
      Index('post', [IndexedColumn('post_id')]),
      Index('comment', [IndexedColumn('comment_id')]),
    ],
  ),
  Table(
    'saved_posts',
    [
      Column.text('user_id'),
      Column.text('post_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
      Index('post', [IndexedColumn('post_id')]),
    ],
  ),
  Table(
    'archived_posts',
    [
      Column.text('user_id'),
      Column.text('post_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
      Index('post', [IndexedColumn('post_id')]),
    ],
  ),
  Table(
    'comments',
    [
      Column.text('post_id'),
      Column.text('user_id'),
      Column.text('content'),
      Column.text('created_at'),
      Column.text('replied_to_comment_id'),
      // Kept by the server: the post's author, the commenter's card (their
      // profile may not be on this phone), the likes and whether the post's
      // author liked it.
      Column.text('post_owner_id'),
      Column.text('author_username'),
      Column.text('author_full_name'),
      Column.text('author_avatar_url'),
      Column.integer('likes_count'),
      Column.integer('liked_by_author'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
      Index('post', [IndexedColumn('post_id')]),
      Index('comment', [IndexedColumn('replied_to_comment_id')]),
    ],
  ),
  Table(
    'subscriptions',
    [
      Column.text('subscriber_id'),
      Column.text('subscribed_to_id'),
      Column.text('created_at'),
      // 'pending' (follow request awaiting approval) or 'accepted'. Older rows
      // synced before this column existed arrive null and read as accepted.
      Column.text('status'),
    ],
    indexes: [
      Index(
        'user',
        [IndexedColumn('subscriber_id'), IndexedColumn('subscribed_to_id')],
      ),
      // Followers lists, counts and "started following you": by the person
      // followed, which the index above (subscriber first) can't serve.
      Index('to', [IndexedColumn('subscribed_to_id')]),
    ],
  ),
  Table(
    'stories',
    [
      Column.text('user_id'),
      Column.text('content_type'),
      Column.text('content_url'),
      Column.integer('duration'),
      Column.text('created_at'),
      Column.text('expires_at'),
      Column.text('location_name'),
      Column.real('location_lat'),
      Column.real('location_lng'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  // Who has viewed each story. One row per (story, viewer). Only the story's
  // author syncs these (the `me` sync stream).
  Table(
    'story_views',
    [
      Column.text('story_id'),
      Column.text('user_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('story', [IndexedColumn('story_id')]),
    ],
  ),
  // Named collections of a user's stories, shown as circles on the profile.
  Table(
    'story_highlights',
    [
      Column.text('user_id'),
      Column.text('name'),
      Column.text('cover_url'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'story_highlight_items',
    [
      Column.text('highlight_id'),
      Column.text('story_id'),
      Column.text('created_at'),
      // The highlight's owner, set by the server (it syncs with the rest of
      // their things).
      Column.text('user_id'),
    ],
    indexes: [
      Index('highlight', [IndexedColumn('highlight_id')]),
    ],
  ),
  // Stories the author hand-pinned to a spot on their travel map. Separate
  // from the location a story was shot at: nothing lands here automatically.
  Table(
    'location_stories',
    [
      Column.text('user_id'),
      Column.text('story_id'),
      Column.text('region_iso'),
      Column.real('lat'),
      Column.real('lng'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('place', [IndexedColumn('user_id'), IndexedColumn('region_iso')]),
    ],
  ),
  // Regions a user marked as visited (onboarding + profile), independent of
  // whether they ever posted from there.
  Table(
    'visited_regions',
    [
      Column.text('user_id'),
      Column.text('region_iso'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'saved_profiles',
    [
      Column.text('saver_id'),
      Column.text('profile_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('saver', [IndexedColumn('saver_id')]),
    ],
  ),
  // Device-local only (never synced, never reverted by PowerSync): the
  // "last opened" timestamp per conversation. `id` = conversation_id. Drives
  // the unread badge, since message is_read updates don't round-trip through
  // sync — see markConversationRead / chatsOf.
  Table.localOnly('chat_last_read', [Column.text('last_read_at')]),
  // Posts a user chose "Don't show again" on. Device-only, per account: they
  // stay out of that user's feed and are never uploaded.
  Table.localOnly('hidden_posts', [
    Column.text('user_id'),
    Column.text('post_id'),
    Column.text('created_at'),
  ]),
]);

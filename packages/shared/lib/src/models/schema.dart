import 'package:powersync/powersync.dart';

/// Global schema in local async SQLite database.
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
      // here, on the globally-synced profile, instead.
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
    ],
  ),
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
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'videos',
    [
      Column.text('owner_id'),
      Column.text('url'),
      Column.text('blur_hash'),
      Column.text('first_frame_url'),
    ],
    indexes: [
      Index('user', [IndexedColumn('owner_id')]),
    ],
  ),
  Table(
    'images',
    [
      Column.text('owner_id'),
      Column.text('url'),
      Column.text('blur_hash'),
    ],
    indexes: [
      Index('user', [IndexedColumn('owner_id')]),
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
    ],
    indexes: [
      Index('user', [IndexedColumn('user_id')]),
      Index('post', [IndexedColumn('post_id')]),
      Index('comment', [IndexedColumn('replied_to_comment_id')]),
    ],
  ),
  Table(
    'conversations',
    [
      Column.text('type'),
      Column.text('name'),
      Column.text('created_at'),
      Column.text('updated_at'),
    ],
  ),
  Table(
    'participants',
    [
      Column.text('user_id'),
      Column.text('conversation_id'),
    ],
    indexes: [
      Index('conversation', [IndexedColumn('conversation_id')]),
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  Table(
    'messages',
    [
      Column.text('conversation_id'),
      Column.text('from_id'),
      Column.text('type'),
      Column.text('message'),
      Column.text('reply_message_id'),
      Column.text('created_at'),
      Column.text('updated_at'),
      Column.integer('is_read'),
      Column.integer('is_deleted'),
      Column.integer('is_edited'),
      Column.text('reply_message_username'),
      Column.text('reply_message_attachment_url'),
      Column.text('shared_post_id'),
      Column.text('shared_story_id'),
      Column.text('reply_message_message'),
      Column.text('from_username'),
    ],
    indexes: [
      Index('conversation', [IndexedColumn('conversation_id')]),
      Index('user', [IndexedColumn('from_id')]),
      Index('message', [IndexedColumn('reply_message_id')]),
      Index('post', [IndexedColumn('shared_post_id')]),
    ],
  ),
  Table(
    'attachments',
    [
      Column.text('message_id'),
      Column.text('title'),
      Column.text('text'),
      Column.text('title_link'),
      Column.text('image_url'),
      Column.text('thumb_url'),
      Column.text('author_name'),
      Column.text('author_link'),
      Column.text('asset_url'),
      Column.text('og_scrape_url'),
      Column.text('type'),
    ],
    indexes: [
      Index('message', [IndexedColumn('message_id')]),
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
  // author syncs these (see the `user_story_views` sync-rule bucket).
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
  // Likes on a story. One row per (story, liker); toggled on/off.
  Table(
    'story_likes',
    [
      Column.text('story_id'),
      Column.text('user_id'),
      Column.text('created_at'),
    ],
    indexes: [
      Index('story', [IndexedColumn('story_id')]),
      Index('user', [IndexedColumn('user_id')]),
    ],
  ),
  // Regions a user marked as visited (onboarding + profile), independent of
  // whether they ever posted from there.
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
  // Typing indicator: one row per (conversation, user), upserted while typing.
  // A fresh updated_at means the user is currently typing.
  Table(
    'typing_status',
    [
      Column.text('conversation_id'),
      Column.text('user_id'),
      Column.text('updated_at'),
    ],
    indexes: [
      Index('conversation', [IndexedColumn('conversation_id')]),
    ],
  ),
  // Read receipts: synced per-(conversation, user) "last read" watermark, so
  // the sender can show ✓✓ once the recipient has read up to a message.
  Table(
    'conversation_reads',
    [
      Column.text('conversation_id'),
      Column.text('user_id'),
      Column.text('last_read_at'),
    ],
    indexes: [
      Index('conversation', [IndexedColumn('conversation_id')]),
    ],
  ),
]);

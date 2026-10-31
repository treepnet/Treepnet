-- Indexes the server's own queries were missing: row-level-security
-- visibility checks (follows, blocks), account deletion, push triggers and
-- tier recompute all looked these columns up with full table scans. Small
-- tables today; they grow with every like, comment and follow.
--
-- Undo: drop the indexes below (nothing depends on them).
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < missing_indexes.sql

begin;

-- "Does A follow B?" (visibility, follow status) and "who follows B".
create index if not exists subscriptions_pair_idx
  on public.subscriptions (subscriber_id, subscribed_to_id);
create index if not exists subscriptions_to_idx
  on public.subscriptions (subscribed_to_id);

-- The blocked-either-way check: (blocker_id, blocked_id) is unique already;
-- this serves the other direction.
create index if not exists blocked_users_blocked_idx
  on public.blocked_users (blocked_id);

-- A post's likes and comments (the unique (user_id, post_id) can't serve a
-- lookup by post alone).
create index if not exists likes_post_idx on public.likes (post_id);
create index if not exists comments_post_idx on public.comments (post_id);
create index if not exists comments_user_idx on public.comments (user_id);

-- A person's posts (tier recompute, profile, deletion).
create index if not exists posts_user_idx on public.posts (user_id);

commit;

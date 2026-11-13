-- Two missing indexes, and six that only repeat the start of another.
--
-- notifications.post_id (a foreign key, ON DELETE CASCADE) had no index: a
-- post's deletion and sync_scoping_on_post's `update notifications ... where
-- post_id` read the whole table. Posts are listed per person newest first
-- (the profile grid, the feed's own and followed posts) with only a
-- user_id index to go on.
--
-- Each dropped index is the first column of another index the same queries
-- use (the planner takes the longer one), and cost every write for nothing.
-- The push queue's 'sending' index came in 026.

create index if not exists notifications_post_idx
  on public.notifications (post_id)
  where post_id is not null;

create index if not exists posts_user_created_idx
  on public.posts (user_id, created_at desc);

drop index if exists public.posts_user_idx;                       -- posts_user_created_idx
drop index if exists public.comments_post_idx;                    -- comments_post_owner_idx (post_id, post_owner_id)
drop index if exists public.story_views_story_idx;                -- story_views_story_id_user_id_key
drop index if exists public.story_highlight_items_highlight_idx;  -- story_highlight_items_highlight_id_story_id_key
drop index if exists public.saved_profiles_saver_idx;             -- saved_profiles_saver_id_profile_id_key
drop index if exists public.visited_regions_user_idx;             -- visited_regions_user_region_key

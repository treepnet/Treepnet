-- The rest of the missing indexes (after missing_indexes.sql). Each column
-- below references another row: deleting a post, story, comment or account
-- made Postgres scan these tables whole to find what goes with it. Plus
-- trigram indexes for people search, whose '%text%' match a plain index
-- can't serve.
--
-- CONCURRENTLY: built without blocking writes, so it runs with the app live —
-- and can't run inside a transaction, hence no begin/commit. A build that
-- fails leaves an INVALID index: drop it and run the file again.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < missing_indexes_2.sql
-- Undo: missing_indexes_2_rollback.sql

create index concurrently if not exists stories_user_idx
  on public.stories (user_id);
create index concurrently if not exists likes_comment_idx
  on public.likes (comment_id) where comment_id is not null;
create index concurrently if not exists comments_replied_to_idx
  on public.comments (replied_to_comment_id) where replied_to_comment_id is not null;
create index concurrently if not exists saved_posts_post_idx
  on public.saved_posts (post_id);
create index concurrently if not exists archived_posts_post_idx
  on public.archived_posts (post_id);
create index concurrently if not exists saved_profiles_profile_idx
  on public.saved_profiles (profile_id);
create index concurrently if not exists story_views_user_idx
  on public.story_views (user_id);
create index concurrently if not exists story_highlight_items_story_idx
  on public.story_highlight_items (story_id);
create index concurrently if not exists location_stories_story_idx
  on public.location_stories (story_id);

-- search_profiles matches search_key(username / full_name) LIKE '%text%'.
create extension if not exists pg_trgm;
create index concurrently if not exists profiles_username_trgm_idx
  on public.profiles using gin (public.search_key(username) gin_trgm_ops);
create index concurrently if not exists profiles_full_name_trgm_idx
  on public.profiles using gin (public.search_key(full_name) gin_trgm_ops);

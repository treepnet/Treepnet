-- Undoes missing_indexes_2.sql (nothing depends on these indexes).
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < missing_indexes_2_rollback.sql

drop index concurrently if exists public.stories_user_idx;
drop index concurrently if exists public.likes_comment_idx;
drop index concurrently if exists public.comments_replied_to_idx;
drop index concurrently if exists public.saved_posts_post_idx;
drop index concurrently if exists public.archived_posts_post_idx;
drop index concurrently if exists public.saved_profiles_profile_idx;
drop index concurrently if exists public.story_views_user_idx;
drop index concurrently if exists public.story_highlight_items_story_idx;
drop index concurrently if exists public.location_stories_story_idx;
drop index concurrently if exists public.profiles_username_trgm_idx;
drop index concurrently if exists public.profiles_full_name_trgm_idx;
-- pg_trgm stays: harmless, and other objects may come to use it.

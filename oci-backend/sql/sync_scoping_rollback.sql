-- Undoes sync_scoping.sql. Only safe while sync-config.yaml is still the old
-- bucket_definitions version: the new sync reads these tables and columns.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet -v ON_ERROR_STOP=1 < sync_scoping_rollback.sql

begin;

drop trigger if exists sync_scoping_on_profile on public.profiles;
drop trigger if exists sync_scoping_on_post on public.posts;
drop trigger if exists comments_fill on public.comments;
drop trigger if exists sync_scoping_on_comment on public.comments;
drop trigger if exists sync_scoping_on_like on public.likes;
drop trigger if exists sync_scoping_on_subscription on public.subscriptions;
drop trigger if exists story_highlight_items_owner on public.story_highlight_items;

drop function if exists public.feed_posts(text, integer, integer, uuid[]);
drop function if exists public.feed_position(uuid, text, uuid[]);
drop function if exists public.post_by_id(uuid);
drop function if exists public.saved_posts_page(integer, integer);
drop function if exists public.feed_post_ids(text, uuid[]);
drop function if exists public.feed_post_rows(uuid[]);
drop type if exists public.feed_post;
drop function if exists public.post_likers(uuid, integer, integer);
drop function if exists public.post_likers_in_followings(uuid[], integer);
drop function if exists public.follow_list(uuid, boolean, integer, integer);
drop function if exists public.suggested_profiles(integer);
drop function if exists public.profile_cards(uuid[]);
drop function if exists public.story_by_id(uuid);

drop function if exists public.sync_scoping_on_profile();
drop function if exists public.sync_scoping_on_post();
drop function if exists public.comments_fill();
drop function if exists public.sync_scoping_on_comment();
drop function if exists public.sync_scoping_on_like();
drop function if exists public.sync_scoping_on_subscription();
drop function if exists public.story_highlight_items_owner();
drop function if exists public.notifications_prune(uuid);
drop function if exists public.notifications_keep();

drop table if exists public.notifications;
drop table if exists public.post_stats;
drop table if exists public.profile_stats;

drop index if exists public.comments_post_owner_idx;
alter table public.comments
  drop column if exists post_owner_id,
  drop column if exists author_username,
  drop column if exists author_full_name,
  drop column if exists author_avatar_url,
  drop column if exists likes_count,
  drop column if exists liked_by_author;

drop index if exists public.story_highlight_items_user_idx;
alter table public.story_highlight_items drop column if exists user_id;

drop function if exists public.post_thumb(text);
drop function if exists public.can_view_author(uuid);

commit;

notify pgrst, 'reload schema';

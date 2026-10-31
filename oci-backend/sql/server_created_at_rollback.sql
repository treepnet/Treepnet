-- Undoes server_created_at.sql: created_at is whatever the app sends again.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < server_created_at_rollback.sql

begin;

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts', 'comments', 'likes', 'story_views', 'story_likes',
    'saved_posts', 'saved_profiles', 'archived_posts', 'visited_regions',
    'story_highlights', 'story_highlight_items', 'location_stories'
  ] loop
    execute format('drop trigger if exists server_created_at on public.%I', t);
  end loop;
end
$$;

drop function if exists public.server_created_at();

commit;

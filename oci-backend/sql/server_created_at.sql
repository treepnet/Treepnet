-- created_at comes from the server's clock, not the phone's.
--
-- The app wrote it: posts and comments from the phone's clock (a phone set
-- ahead kept its post on top of the feed), and story views, saves, archive,
-- visited regions, highlights and place stories as local time without a
-- zone, which this UTC server read as UTC — 5 hours ahead in Tashkent, 3 in
-- Moscow. On insert the server's now() is used; on update the original is
-- kept, so a re-upload (PowerSync upserts) can't move it either. Stories and
-- presence already work this way (stories_server_times, track_presence).
-- Rows written before stay as they are.
--
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < server_created_at.sql
-- Undo: server_created_at_rollback.sql

begin;

create or replace function public.server_created_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

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
    execute format(
      'create trigger server_created_at before insert or update on public.%I '
      'for each row execute function public.server_created_at()', t);
  end loop;
end
$$;

commit;

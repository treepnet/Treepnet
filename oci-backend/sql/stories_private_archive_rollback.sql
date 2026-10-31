-- Undoes stories_private_archive.sql: every story is readable by everyone
-- again. Revert powersync/sync-config.yaml (global_stories without the
-- visibility filter, no user_own_stories) and restart PowerSync FIRST — its
-- rules read the column dropped here. Also remove the refresh_story_visibility
-- cron line.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < stories_private_archive_rollback.sql

begin;

drop policy if exists stories_select on public.stories;
drop policy if exists "Everybody can see each others stories." on public.stories;
create policy "Everybody can see each others stories." on public.stories
  for select
  using (true);

drop trigger if exists story_highlight_items_visibility on public.story_highlight_items;
drop trigger if exists location_stories_visibility on public.location_stories;
drop trigger if exists stories_visibility on public.stories;
drop function if exists public.story_links_changed();
drop function if exists public.refresh_story_visibility(uuid);
drop function if exists public.stories_set_visibility();
drop function if exists public.story_visibility(uuid, timestamptz);

alter table public.stories drop column if exists visibility;

commit;

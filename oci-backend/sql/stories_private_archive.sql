-- Archived stories are the author's alone, as the archive promises.
--
-- Before: sync rules sent every story ever posted (with its location) to every
-- phone, and RLS let anyone read them, although the archive tells its owner
-- "Only you can see them". The data also grew forever on every device.
--
-- After: stories.visibility is kept by the server:
--   'public' — still live (its 24 h aren't up), or its author keeps it on show
--              in a highlight or pinned to a place;
--   'owner'  — everything else: only its author can read or sync it.
-- A BEFORE trigger sets it on every insert/update (so a client can't set it),
-- adding/removing a highlight item or a pin re-checks that story at once, and
-- refresh_story_visibility() — run by cron every 5 minutes — turns stories
-- whose 24 hours ran out into 'owner':
--   */5 * * * * docker exec treepnet-postgres psql -U treepnet -d treepnet -qAt -c "select public.refresh_story_visibility()" >/dev/null 2>&1
-- Sync rules: global_stories carries only 'public' stories, user_own_stories
-- all of the user's own (powersync/sync-config.yaml).
--
-- Undo: stories_private_archive_rollback.sql (revert the sync rules first).
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < stories_private_archive.sql

begin;

alter table public.stories
  add column if not exists visibility text not null default 'public'
  constraint stories_visibility_check check (visibility in ('public', 'owner'));

create or replace function public.story_visibility(p_id uuid, p_expires_at timestamptz)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p_expires_at > now()
      or exists (select 1 from story_highlight_items i where i.story_id = p_id)
      or exists (select 1 from location_stories l where l.story_id = p_id)
    then 'public'
    else 'owner'
  end
$$;

create or replace function public.stories_set_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.visibility := story_visibility(new.id, new.expires_at);
  return new;
end;
$$;

-- BEFORE triggers fire in name order: after stories_server_times, which sets
-- expires_at on insert.
drop trigger if exists stories_visibility on public.stories;
create trigger stories_visibility
  before insert or update on public.stories
  for each row execute function public.stories_set_visibility();

-- Re-checks [p_story], or every story; returns how many changed.
create or replace function public.refresh_story_visibility(p_story uuid default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update stories s
     set visibility = story_visibility(s.id, s.expires_at)
   where (p_story is null or s.id = p_story)
     and s.visibility is distinct from story_visibility(s.id, s.expires_at);
  get diagnostics changed = row_count;
  return changed;
end;
$$;

create or replace function public.story_links_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform refresh_story_visibility(old.story_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform refresh_story_visibility(new.story_id);
  end if;
  return null;
end;
$$;

drop trigger if exists story_highlight_items_visibility on public.story_highlight_items;
create trigger story_highlight_items_visibility
  after insert or update or delete on public.story_highlight_items
  for each row execute function public.story_links_changed();

drop trigger if exists location_stories_visibility on public.location_stories;
create trigger location_stories_visibility
  after insert or update or delete on public.location_stories
  for each row execute function public.story_links_changed();

revoke all on function public.story_visibility(uuid, timestamptz) from public, authenticated;
revoke all on function public.stories_set_visibility() from public, authenticated;
revoke all on function public.refresh_story_visibility(uuid) from public, authenticated;
revoke all on function public.story_links_changed() from public, authenticated;

drop policy if exists "Everybody can see each others stories." on public.stories;
drop policy if exists stories_select on public.stories;
create policy stories_select on public.stories
  for select
  using (visibility = 'public' or auth.uid() = user_id);

select public.refresh_story_visibility() as stories_made_private;

commit;

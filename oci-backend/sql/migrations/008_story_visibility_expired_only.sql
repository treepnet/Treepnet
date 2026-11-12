-- The five-minute story job looks only at stories that can still change.
--
-- refresh_story_visibility() with no story re-evaluated every story ever
-- posted, every five minutes. A story's visibility changes on its own only
-- when its 24 hours run out: inserts, updates, and adding it to or removing it
-- from a highlight or a place already re-evaluate it (the stories_visibility
-- and story_links_changed triggers). So the job now takes the public ones
-- whose time is up: the ones expiring now, and those kept public by a
-- highlight or a place (bounded by how many of those there are, not by every
-- story ever posted). Called with a story, it is unchanged.

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
   where (case
            when p_story is null then s.visibility = 'public' and s.expires_at <= now()
            else s.id = p_story
          end)
     and s.visibility is distinct from story_visibility(s.id, s.expires_at);
  get diagnostics changed = row_count;
  return changed;
end;
$$;

revoke all on function public.refresh_story_visibility(uuid) from public, anon, authenticated;

create index if not exists stories_public_by_expiry
  on public.stories (expires_at)
  where visibility = 'public';

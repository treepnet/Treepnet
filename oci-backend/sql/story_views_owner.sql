-- story_views.story_owner_id: lets PowerSync sync all of a user's story views
-- in ONE bucket.
--
-- Before: the user_story_views bucket was parameterised per story
-- (`select id as story_id from stories where user_id = request.user_id()`), so
-- every story ever posted opened another bucket. Stories are never deleted
-- (archive, highlights and map pins depend on them) and PowerSync caps one
-- connection at 1,000 buckets — past that it stops syncing EVERYTHING for that
-- user, silently. Sync-rule parameter queries can't join, so the owner is
-- denormalised onto the view row instead.
--
-- The owner is always set by the server (trigger below, security definer so
-- it still works if stories ever get a non-public SELECT policy). Clients
-- (including old app versions) never send it, and a value they do send is
-- overwritten.
--
-- Apply as the DB superuser BEFORE deploying the matching sync-config.yaml:
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < story_views_owner.sql

begin;

alter table public.story_views add column if not exists story_owner_id uuid;

update public.story_views v
   set story_owner_id = s.user_id
  from public.stories s
 where s.id = v.story_id
   and v.story_owner_id is distinct from s.user_id;

create or replace function public.story_views_set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select s.user_id into new.story_owner_id
    from public.stories s
   where s.id = new.story_id;
  return new;
end;
$$;

drop trigger if exists story_views_set_owner on public.story_views;
create trigger story_views_set_owner
  before insert or update of story_id, story_owner_id on public.story_views
  for each row execute function public.story_views_set_owner();

alter table public.story_views alter column story_owner_id set not null;

create index if not exists story_views_owner_idx
  on public.story_views (story_owner_id);

commit;

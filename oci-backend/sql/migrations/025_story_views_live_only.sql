-- Only the views of a story still shown (in its 24 hours, or kept in a
-- highlight or on the map) go to its owner's phone; an archived story's are
-- asked for when the owner opens it.
--
-- The `me` sync stream sent every view of every story the user ever posted,
-- on every fresh install: it grows with the account's whole history (three
-- stories a day seen by a thousand people is about a million rows a year),
-- while the app shows the views of one story at a time.
--
-- story_views.story_visibility mirrors stories.visibility (kept by triggers,
-- as that one is by refresh_story_visibility), so the sync rules can filter
-- on the row itself; a story going to the archive takes its views off the
-- phone, one brought back (pinned again) puts them back. The app (1.0.9+)
-- asks story_view_count / story_viewer_ids for an archived story; an older
-- build shows such a story's views as none.

alter table public.story_views
  add column if not exists story_visibility text not null default 'public';

update public.story_views v
   set story_visibility = s.visibility
  from public.stories s
 where s.id = v.story_id
   and v.story_visibility is distinct from s.visibility;

-- A new view takes its story's owner (as before, 023) and visibility.
create or replace function public.story_views_set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select s.user_id, s.visibility
    into new.story_owner_id, new.story_visibility
    from public.stories s
   where s.id = new.story_id;
  if tg_op = 'INSERT' and new.user_id = auth.uid() and (
       new.story_owner_id is null
       or new.story_owner_id = new.user_id
       or not public.can_view_author(new.story_owner_id)) then
    return null;
  end if;
  return new;
end;
$$;

-- A story's visibility changing moves its views with it. Any update: the
-- visibility is also set by stories_set_visibility on other changes (an
-- expired story edited), and UPDATE OF would miss those.
create or replace function public.story_views_follow_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.story_views
     set story_visibility = new.visibility
   where story_id = new.id
     and story_visibility is distinct from new.visibility;
  return null;
end;
$$;

revoke all on function public.story_views_follow_visibility() from public, anon, authenticated;

drop trigger if exists story_views_follow_visibility on public.stories;
create trigger story_views_follow_visibility
  after update on public.stories
  for each row
  when (old.visibility is distinct from new.visibility)
  execute function public.story_views_follow_visibility();

-- For the owner: how many people saw a story of theirs, and who, newest
-- first (blocked people left out, as the app's list does). Anyone else gets
-- nothing.
create or replace function public.story_view_count(p_story uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
    from public.story_views v
   where v.story_id = p_story
     and v.story_owner_id = auth.uid()
     and not public.blocked_between(auth.uid(), v.user_id)
$$;

create or replace function public.story_viewer_ids(p_story uuid, p_limit integer default 30)
returns table (user_id uuid, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select v.user_id, v.created_at
    from public.story_views v
   where v.story_id = p_story
     and v.story_owner_id = auth.uid()
     and not public.blocked_between(auth.uid(), v.user_id)
   order by v.created_at desc
   limit least(greatest(coalesce(p_limit, 30), 1), 1000)
$$;

revoke all on function public.story_view_count(uuid) from public, anon;
revoke all on function public.story_viewer_ids(uuid, integer) from public, anon;
grant execute on function public.story_view_count(uuid) to authenticated;
grant execute on function public.story_viewer_ids(uuid, integer) to authenticated;

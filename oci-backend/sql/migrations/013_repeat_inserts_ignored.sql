-- Doing something twice is not an error: a like, follow, saved post or
-- profile, archived post, block, visited region, story pin or highlight item
-- that is already there is dropped quietly instead of failing, as a second
-- story view already was (003).
--
-- The app decides "like" or "unlike", "follow" or "unfollow" from what is on
-- the phone. Right after signing in, on a second phone or after a reinstall
-- the phone doesn't have the server's rows yet, so a tap sends one that
-- already exists; a retry after a lost response sends one that was saved.
-- The unique key refused it (a retry of the same row met the id instead, and
-- these tables have no UPDATE policy for the upsert to take). The app treats
-- either as final: it showed "Change not saved", filed a crash report, and
-- dropped the rest of that save (a pin's highlight item, the regions after
-- the refused one), though the server already held what the user wanted.
-- Older builds benefit at once.
--
-- Only the caller's own rows are skipped. Skipping a row someone writes in
-- another person's name would tell them, by success or refusal, whether that
-- person already likes, follows, saved or blocked something (or has seen a
-- story: 003 had that hole, closed below); such a row goes on to the policies
-- and is refused as before. No signed-in user (server code): unchanged.
--
-- BEFORE triggers fire in name order, and a NULL return skips the ones after
-- it: subscriptions_enforce (a block still refuses a follow) runs first.

create or replace function public.ignore_repeat_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  repeated boolean;
begin
  if me is null then
    return new;
  end if;
  case tg_table_name
    when 'subscriptions' then
      repeated := new.subscriber_id = me and exists (
        select 1 from subscriptions s
         where s.subscriber_id = new.subscriber_id
           and s.subscribed_to_id = new.subscribed_to_id);
    when 'likes' then
      repeated := new.user_id = me and exists (
        select 1 from likes l
         where l.user_id = new.user_id
           and ((new.post_id is not null and l.post_id = new.post_id)
             or (new.comment_id is not null and l.comment_id = new.comment_id)));
    when 'saved_posts' then
      repeated := new.user_id = me and exists (
        select 1 from saved_posts s
         where s.user_id = new.user_id and s.post_id = new.post_id);
    when 'saved_profiles' then
      repeated := new.saver_id = me and exists (
        select 1 from saved_profiles s
         where s.saver_id = new.saver_id and s.profile_id = new.profile_id);
    when 'archived_posts' then
      repeated := new.user_id = me and exists (
        select 1 from archived_posts a
         where a.user_id = new.user_id and a.post_id = new.post_id);
    when 'blocked_users' then
      repeated := new.blocker_id = me and exists (
        select 1 from blocked_users b
         where b.blocker_id = new.blocker_id and b.blocked_id = new.blocked_id);
    when 'visited_regions' then
      repeated := new.user_id = me and exists (
        select 1 from visited_regions v
         where v.user_id = new.user_id and v.region_iso = new.region_iso);
    when 'location_stories' then
      -- Same as its unique key, which treats an absent lat/lng as equal.
      repeated := new.user_id = me and exists (
        select 1 from location_stories l
         where l.user_id = new.user_id
           and l.story_id = new.story_id
           and l.region_iso = new.region_iso
           and l.lat is not distinct from new.lat
           and l.lng is not distinct from new.lng);
    when 'story_highlight_items' then
      -- The item's owner is the highlight's (story_highlight_items_owner
      -- fills user_id in after this trigger).
      repeated := exists (
          select 1 from story_highlights h
           where h.id = new.highlight_id and h.user_id = me)
        and exists (
          select 1 from story_highlight_items i
           where i.highlight_id = new.highlight_id
             and i.story_id = new.story_id);
    else
      return new;
  end case;
  if coalesce(repeated, false) then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.ignore_repeat_insert() from public, anon, authenticated;

drop trigger if exists subscriptions_ignore_repeat on public.subscriptions;
create trigger subscriptions_ignore_repeat
  before insert on public.subscriptions
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists likes_ignore_repeat on public.likes;
create trigger likes_ignore_repeat
  before insert on public.likes
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists saved_posts_ignore_repeat on public.saved_posts;
create trigger saved_posts_ignore_repeat
  before insert on public.saved_posts
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists saved_profiles_ignore_repeat on public.saved_profiles;
create trigger saved_profiles_ignore_repeat
  before insert on public.saved_profiles
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists archived_posts_ignore_repeat on public.archived_posts;
create trigger archived_posts_ignore_repeat
  before insert on public.archived_posts
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists blocked_users_ignore_repeat on public.blocked_users;
create trigger blocked_users_ignore_repeat
  before insert on public.blocked_users
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists visited_regions_ignore_repeat on public.visited_regions;
create trigger visited_regions_ignore_repeat
  before insert on public.visited_regions
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists location_stories_ignore_repeat on public.location_stories;
create trigger location_stories_ignore_repeat
  before insert on public.location_stories
  for each row execute function public.ignore_repeat_insert();

drop trigger if exists story_highlight_items_ignore_repeat on public.story_highlight_items;
create trigger story_highlight_items_ignore_repeat
  before insert on public.story_highlight_items
  for each row execute function public.ignore_repeat_insert();

-- 003's trigger, now for the viewer's own views only.
create or replace function public.story_views_ignore_repeat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.user_id = auth.uid() and exists (
       select 1 from story_views v
        where v.story_id = new.story_id and v.user_id = new.user_id) then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.story_views_ignore_repeat() from public, anon, authenticated;

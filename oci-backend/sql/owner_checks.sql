-- Make the server, not the app, decide who a new row belongs to.
--
-- Before: adding a post, comment, like, story, profile or follow only required
-- being signed in (`with check (true)`), so anyone could call the API and write
-- rows under SOMEONE ELSE's id. A follower also chose the follow's status
-- itself, so it could write 'accepted' straight into a private account and skip
-- the request. Story times came from the phone's clock, so a wrong clock made a
-- story last for days or vanish early. And anyone could list every story view
-- through the API.
--
-- After:
--   * a new post / comment / like / story must carry the caller's own user_id,
--     a new profile the caller's own id, a new follow the caller as subscriber;
--   * a story's owner cannot move it to another user;
--   * the server sets a follow's status: 'pending' for a private account,
--     'accepted' for a public one. A block either way refuses the follow;
--   * the account owner, accepting a request, can change only its status — not
--     who follows whom;
--   * the server stamps a story's created_at and its 24-hour expires_at; later
--     edits (e.g. the location) cannot move them;
--   * a story view is readable only by the viewer and the story's owner (what
--     the sync rules already do, now on the API too).
--
-- The app already writes rows exactly this way, so valid writes are unchanged.
-- The auth, delete-account and push services connect as the table owner and
-- are not affected by the policies. A refused write reaches the app as 42501:
-- the upload connector drops it and reports it (RejectedUpload).
--
-- Undo: owner_checks_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < owner_checks.sql

begin;

-- 1. Owner checks on insert.
alter policy "Allow upload post only to authenticated user." on public.posts
  with check (auth.uid() = user_id);
alter policy "Only authenticated can upload comments." on public.comments
  with check (auth.uid() = user_id);
alter policy "Only authenticated can upload likes" on public.likes
  with check (auth.uid() = user_id);
alter policy "Only authenticated users can add stories." on public.stories
  with check (auth.uid() = user_id);
alter policy "Allow to create profiles for everyone." on public.profiles
  with check (auth.uid() = id);
alter policy "Only authenticated users can subscribe to other users." on public.subscriptions
  with check (auth.uid() = subscriber_id);

-- 2. A story stays its owner's after an edit.
alter policy "Only owners can update stories." on public.stories
  with check (auth.uid() = user_id);

-- 3. Story views: only the viewer and the story's owner.
alter policy story_views_select on public.story_views
  using (auth.uid() = user_id or auth.uid() = story_owner_id);

-- 4. Follow status and blocks, decided by the server.
create or replace function public.subscriptions_enforce()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if exists (
      select 1 from public.blocked_users b
       where (b.blocker_id = new.subscriber_id and b.blocked_id = new.subscribed_to_id)
          or (b.blocker_id = new.subscribed_to_id and b.blocked_id = new.subscriber_id)
    ) then
      raise exception 'cannot follow: blocked' using errcode = '42501';
    end if;
    new.status := case
      when coalesce((select p.is_private from public.profiles p
                      where p.id = new.subscribed_to_id), false)
        then 'pending'
      else 'accepted'
    end;
  else
    if new.subscriber_id is distinct from old.subscriber_id
       or new.subscribed_to_id is distinct from old.subscribed_to_id then
      raise exception 'cannot change who follows whom' using errcode = '42501';
    end if;
    if new.status is null or new.status not in ('pending', 'accepted') then
      raise exception 'invalid follow status' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.subscriptions_enforce() from public, authenticated;

drop trigger if exists subscriptions_enforce on public.subscriptions;
create trigger subscriptions_enforce
  before insert or update on public.subscriptions
  for each row execute function public.subscriptions_enforce();

-- 5. Story times from the server's clock.
create or replace function public.stories_server_times()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.expires_at := now() + interval '24 hours';
  else
    new.created_at := old.created_at;
    new.expires_at := old.expires_at;
  end if;
  return new;
end;
$$;

revoke all on function public.stories_server_times() from public, authenticated;

drop trigger if exists stories_server_times on public.stories;
create trigger stories_server_times
  before insert or update on public.stories
  for each row execute function public.stories_server_times();

commit;

-- The app's "I'm here" beat as one small call, not a write to the profile.
--
-- The app wrote profiles.last_seen_at through its sync database every 45 s.
-- Nearly every screen watches that table, so each beat re-ran the feed, the
-- notification badge, comments, every badge and the stories tray on the phone
-- (twice: once more when the server's copy came back), sent two requests and
-- often a feed check, and offline it queued in front of the user's own posts.
-- The server never kept the value on the profile anyway (profiles_quiet_updates
-- moves it to profile_presence).
--
-- touch_presence() records the same as the old path did: the time in
-- profile_presence (admin "last seen", DAU/WAU/MAU) and the minute in
-- analytics.activity (admin "online now", sessions). Builds that still write
-- last_seen_at keep working through track_presence + profiles_quiet_updates.

create or replace function public.touch_presence()
returns void
language plpgsql
security definer
set search_path = public, analytics
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    return;
  end if;
  insert into profile_presence (user_id, last_seen_at)
  values (me, now())
  on conflict (user_id) do update
    set last_seen_at = greatest(profile_presence.last_seen_at, excluded.last_seen_at);
  insert into analytics.activity (user_id, minute)
  values (me, date_trunc('minute', now()))
  on conflict do nothing;
end;
$$;

revoke all on function public.touch_presence() from public, anon;
grant execute on function public.touch_presence() to authenticated;

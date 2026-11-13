-- When someone last opened their notifications, and when they finished the
-- intro, are theirs alone, and the server's clock sets them.
--
-- notifications_seen_at is in effect a "last active" time (last_seen_at was
-- made private for that reason); any signed-in user could read it, and
-- onboarded_at, through the API (GET /profiles?select=...). The app reads
-- both from its sync, never from the API. (The sync still carries them to a
-- person's followers and profile cards until the app that reads them from
-- my_profile is on every phone: see powersync/sync-config.yaml.)
--
-- Both were written with the phone's clock, and notifications_seen_at is
-- compared with the server-stamped times of notifications: on a phone whose
-- clock was off, the unread badge hid new ones or kept counting old ones. The
-- server's now() replaces whatever the phone sends (never a clear to NULL).

revoke select (notifications_seen_at, onboarded_at) on public.profiles from authenticated;

create or replace function public.profiles_server_stamps()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.notifications_seen_at is distinct from old.notifications_seen_at
     and new.notifications_seen_at is not null then
    new.notifications_seen_at := now();
  end if;
  if new.onboarded_at is distinct from old.onboarded_at
     and new.onboarded_at is not null then
    new.onboarded_at := now();
  end if;
  return new;
end;
$$;

revoke all on function public.profiles_server_stamps() from public, anon, authenticated;

-- Before zz_profiles_quiet_updates (BEFORE triggers fire in name order),
-- which drops an update that changes nothing.
drop trigger if exists profiles_server_stamps on public.profiles;
create trigger profiles_server_stamps
  before update of notifications_seen_at, onboarded_at on public.profiles
  for each row execute function public.profiles_server_stamps();

-- Keep the "online" heartbeat off the profile row, so it isn't sent to every phone.
--
-- Before: the app stamps profiles.last_seen_at every 45 s while open and
-- re-writes an unchanged push token on each start. PowerSync re-sends a
-- profile row to every device (global_profiles) whenever ANY of its columns is
-- written — even ones that bucket doesn't carry, even when nothing changed
-- (checked on prod 2026-10-31) — so each active user made every phone download
-- and re-run its queries every 45 s: traffic and battery growing with the
-- square of the user count, for a value the app doesn't read.
--
-- After: an update that only moves last_seen_at stores the time in
-- profile_presence (synced to nobody) and leaves the profile row alone; an
-- update that changes nothing (e.g. the same push token) isn't applied at all.
-- Either way PowerSync sees no change and sends nothing. The client still gets
-- a normal success. analytics.users / analytics.active_users (admin DAU/WAU/MAU
-- and "last seen") read the time from profile_presence; "online now" keeps
-- using analytics.activity, which track_presence still fills.
--
-- Undo: presence_table_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < presence_table.sql

begin;

create table if not exists public.profile_presence (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  last_seen_at timestamptz not null
);
alter table public.profile_presence enable row level security;
revoke all on table public.profile_presence from public, authenticated;

insert into public.profile_presence (user_id, last_seen_at)
select id, last_seen_at from public.profiles where last_seen_at is not null
on conflict (user_id) do nothing;

create or replace function public.profiles_quiet_updates()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The heartbeat: keep the time aside (track_presence has already set it to
  -- the server clock and recorded the analytics minute).
  if new.last_seen_at is distinct from old.last_seen_at then
    insert into profile_presence (user_id, last_seen_at)
    values (new.id, new.last_seen_at)
    on conflict (user_id) do update
      set last_seen_at = greatest(profile_presence.last_seen_at, excluded.last_seen_at);
    new.last_seen_at := old.last_seen_at;
  end if;
  -- Nothing left to change: skip the write, so nothing is replicated.
  if new is not distinct from old then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.profiles_quiet_updates() from public, authenticated;

-- BEFORE triggers fire in name order: this one must run after track_presence.
drop trigger if exists zz_profiles_quiet_updates on public.profiles;
create trigger zz_profiles_quiet_updates
  before update on public.profiles
  for each row execute function public.profiles_quiet_updates();

create or replace view analytics.active_users as
select
  count(*) filter (where s.seen >= now() - interval '1 day') as dau,
  count(*) filter (where s.seen >= now() - interval '7 days') as wau,
  count(*) filter (where s.seen >= now() - interval '30 days') as mau
from (
  select coalesce(pp.last_seen_at, p.last_seen_at) as seen
    from public.profiles p
    left join public.profile_presence pp on pp.user_id = p.id
) s;

create or replace view analytics.users as
select p.id,
    p.username,
    p.avatar_url is not null and p.avatar_url <> ''::text as has_avatar,
    p.bio is not null and p.bio <> ''::text as has_bio,
    p.is_private,
    p.referral_tier,
    extract(year from p.birthday)::integer as birth_year,
    p.push_token is not null and p.push_token <> ''::text as has_push_token,
    coalesce(pp.last_seen_at, p.last_seen_at) as last_seen_at,
    coalesce(c.created_at, (select min(x.ts) as min
           from (select min(posts.created_at) as ts from posts where posts.user_id = p.id
                 union all
                 select min(stories.created_at) as min from stories where stories.user_id = p.id
                 union all
                 select min(likes.created_at) as min from likes where likes.user_id = p.id
                 union all
                 select min(comments.created_at) as min from comments where comments.user_id = p.id
                 union all
                 select min(subscriptions.created_at) as min from subscriptions where subscriptions.subscriber_id = p.id
                 union all
                 select min(visited_regions.created_at) as min from visited_regions where visited_regions.user_id = p.id) x)) as signup_at,
    c.created_at is null as signup_estimated,
    p.onboarded_at
   from profiles p
     left join auth_credentials c on c.user_id = p.id
     left join profile_presence pp on pp.user_id = p.id;

commit;

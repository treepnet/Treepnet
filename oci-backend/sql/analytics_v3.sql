-- Treepnet admin analytics v3: presence log, server-time last_seen, more views.
-- Apply as the DB superuser AFTER analytics.sql + analytics_v2.sql:
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < analytics_v3.sql
-- Additive and idempotent. Exposes no PII to analytics_ro.

begin;

-- 1. Presence log ------------------------------------------------------------
-- One row per (user, minute) in which the app's foreground heartbeat (every
-- 45 s, profiles.last_seen_at) arrived. It powers "online now", per-day active
-- users and session lengths, none of which can be derived from the single
-- point-in-time last_seen_at. Not in any PowerSync bucket.
create table if not exists analytics.activity (
  user_id uuid        not null,
  minute  timestamptz not null,
  primary key (user_id, minute)
);
create index if not exists activity_minute_idx on analytics.activity (minute);

-- 2. Heartbeat trigger ------------------------------------------------------
-- The app writes last_seen_at as device-local wall-clock time with no offset,
-- which Postgres stores as UTC: Uzbek users appear ~5 h in the future and drop
-- out of "active" windows. Stamp it with server time instead, and log the
-- minute. SECURITY DEFINER so the PostgREST role needs no rights on analytics.
create or replace function public.track_presence()
returns trigger
language plpgsql
security definer
set search_path = public, analytics
as $$
begin
  new.last_seen_at := now();
  insert into analytics.activity (user_id, minute)
  values (new.id, date_trunc('minute', now()))
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists track_presence on public.profiles;
create trigger track_presence
  before update of last_seen_at on public.profiles
  for each row
  when (new.last_seen_at is distinct from old.last_seen_at)
  execute function public.track_presence();

-- 3. Views -------------------------------------------------------------------
-- Registration time: auth_credentials.created_at for accounts made through
-- auth-service; older/legacy accounts without a credentials row fall back to
-- their first recorded activity (flagged as an estimate).
create or replace view analytics.users as
  select
    p.id,
    p.username,
    (p.avatar_url is not null and p.avatar_url <> '') as has_avatar,
    (p.bio is not null and p.bio <> '')               as has_bio,
    p.is_private,
    p.referral_tier,
    extract(year from p.birthday)::int                as birth_year,
    (p.push_token is not null and p.push_token <> '') as has_push_token,
    p.last_seen_at,
    coalesce(
      c.created_at,
      (select min(ts) from (
         select min(created_at) ts from public.posts           where user_id = p.id
         union all select min(created_at) from public.stories  where user_id = p.id
         union all select min(created_at) from public.likes    where user_id = p.id
         union all select min(created_at) from public.comments where user_id = p.id
         union all select min(created_at) from public.subscriptions where subscriber_id = p.id
         union all select min(created_at) from public.visited_regions where user_id = p.id
       ) x)
    )                                                 as signup_at,
    (c.created_at is null)                            as signup_estimated,
    p.onboarded_at
  from public.profiles p
  left join public.auth_credentials c on c.user_id = p.id;

-- last_seen_at may still hold a "future" device-local value until the user's
-- next heartbeat, so don't cap the windows at now().
create or replace view analytics.active_users as
  select
    count(*) filter (where last_seen_at >= now() - interval '1 day')   as dau,
    count(*) filter (where last_seen_at >= now() - interval '7 days')  as wau,
    count(*) filter (where last_seen_at >= now() - interval '30 days') as mau
  from public.profiles;

create or replace view analytics.saves as
  select user_id, post_id, created_at from public.saved_posts;

create or replace view analytics.highlights as
  select id, user_id, created_at from public.story_highlights;

create or replace view analytics.story_view_events as
  select story_id, created_at from public.story_views;

-- 4. Grants -------------------------------------------------------------------
grant select on analytics.activity, analytics.users, analytics.active_users,
  analytics.saves, analytics.highlights, analytics.story_view_events
  to analytics_ro;

commit;

-- 5. Follow status (added after v3's first apply): pending requests must not
-- count as followers in the panel.
create or replace view analytics.follows as
  select id, subscriber_id, subscribed_to_id, created_at, coalesce(status, 'accepted') as status
  from public.subscriptions;
grant select on analytics.follows to analytics_ro;

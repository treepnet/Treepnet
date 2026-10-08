-- Treepnet admin analytics — additions for the custom admin panel
-- (github.com/Hikmatbek-dev/Treepnet-admin-panel). Apply as the DB superuser,
-- AFTER analytics.sql:
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -f - < analytics_v2.sql
--
-- Everything here is additive and idempotent. It only exposes aggregate-safe
-- columns, like analytics.sql, and the read-only analytics_ro role is granted
-- SELECT on the new objects at the bottom.

-- 1. Story view counts ------------------------------------------------------
-- public.story_views holds one row per (story, viewer). Expose only the count
-- per story (no viewer identities) so the panel can show story reach.
create or replace view analytics.story_views as
  select story_id, count(*)::bigint as views_count
  from public.story_views
  group by story_id;

-- 2. Referral leaderboard ---------------------------------------------------
-- IMPORTANT: profiles.referral_tier now holds the TRAVEL COLOUR (1-5), not an
-- invite rank, so the panel's referral tiers must be derived from the actual
-- invite graph instead. One row per referrer with how many sign-ups they
-- brought. The panel maps the count to Bronze/Silver/Gold/Platinum.
create or replace view analytics.referral_counts as
  select
    r.referrer_id          as user_id,
    p.username,
    count(*)::bigint       as invited_count
  from public.referrals r
  join public.profiles p on p.id = r.referrer_id
  group by r.referrer_id, p.username;

-- 3. Daily active-user snapshot ---------------------------------------------
-- profiles.last_seen_at is point-in-time (the 45s foreground heartbeat
-- overwrites it), so historical DAU/WAU/MAU cannot be reconstructed from it.
-- This table captures one row per day (written by a nightly cron on the host,
-- running as the superuser) so the trend charts have real history going
-- forward. Read-only for analytics_ro.
create table if not exists analytics.daily_active (
  day     date primary key,
  dau     integer not null,
  wau     integer not null,
  mau     integer not null,
  signups integer not null default 0
);

-- Seed today's row immediately so the chart isn't empty on first load. The
-- nightly cron keeps it current and appends new days (see deploy notes).
insert into analytics.daily_active (day, dau, wau, mau, signups)
select
  current_date,
  a.dau, a.wau, a.mau,
  (select count(*) from analytics.signups
    where created_at >= current_date and created_at < current_date + 1)
from analytics.active_users a
on conflict (day) do update
  set dau = excluded.dau,
      wau = excluded.wau,
      mau = excluded.mau,
      signups = excluded.signups;

-- 4. Grant the read-only role SELECT on the new objects ---------------------
grant select on analytics.story_views    to analytics_ro;
grant select on analytics.referral_counts to analytics_ro;
grant select on analytics.daily_active    to analytics_ro;

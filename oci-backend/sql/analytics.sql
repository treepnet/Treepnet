-- Treepnet admin analytics — read-only views + grants for Metabase.
--
-- Exposes ONLY aggregate-safe columns. NEVER exposes: email, password hash, OTP
-- codes, push tokens, full names, avatar/media URLs, or message/comment TEXT.
--
-- The two DB roles (analytics_ro, metabase_app) are created separately with
-- passwords from the server .env (kept out of git). This file only needs them to
-- already exist for the GRANT / ALTER ROLE statements at the bottom.
--
-- Apply as the DB superuser so the views are owned by a privileged role and can
-- read the base tables on analytics_ro's behalf (PG16 views are definer by
-- default): docker exec treepnet-postgres psql -U <super> -d treepnet -f analytics.sql

-- 1. Registration timestamp. On the NON-synced auth_credentials, NOT profiles
--    (profiles is globally PowerSync-replicated). auth-service already inserts a
--    row per signup, so DEFAULT now() backfills new signups with no code change.
--    Existing rows get the migration time (no UPDATE backfill -> no sync storm).
alter table public.auth_credentials
  add column if not exists created_at timestamptz default now();

-- 2. Dedicated schema for the analytics surface.
create schema if not exists analytics;

-- 3. PII-safe views ---------------------------------------------------------

create or replace view analytics.signups as
  select user_id, created_at
  from public.auth_credentials;

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
    c.created_at                                      as signup_at
  from public.profiles p
  left join public.auth_credentials c on c.user_id = p.id;

create or replace view analytics.posts as
  select id, user_id, created_at,
    (location is not null) as has_location,
    location_country, location_region, location_name
  from public.posts;

create or replace view analytics.stories as
  select id, user_id, created_at, expires_at,
    content_type::text        as content_type,
    (expires_at > now())      as is_active
  from public.stories;

create or replace view analytics.comments as
  select id, post_id, user_id, created_at,
    (replied_to_comment_id is not null) as is_reply
  from public.comments;

create or replace view analytics.likes as
  select id, post_id, comment_id, user_id, created_at
  from public.likes;

create or replace view analytics.follows as
  select id, subscriber_id, subscribed_to_id, created_at
  from public.subscriptions;

create or replace view analytics.referrals as
  select referrer_id, invited_id, created_at
  from public.referrals;

create or replace view analytics.messages as
  select id, conversation_id, from_id, type::text as type, created_at
  from public.messages;

create or replace view analytics.conversations as
  select id, created_at
  from public.conversations;

create or replace view analytics.blocked as
  select blocker_id, blocked_id, created_at
  from public.blocked_users;

create or replace view analytics.visited_regions as
  select user_id, region_iso, created_at
  from public.visited_regions;

create or replace view analytics.push as
  select recipient_id, type, status, created_at, sent_at
  from public.push_outbox;

-- Rollups (single-row convenience) -----------------------------------------

create or replace view analytics.active_users as
  select
    count(*) filter (where last_seen_at >= now() - interval '1 day'
                       and last_seen_at <= now()) as dau,
    count(*) filter (where last_seen_at >= now() - interval '7 days'
                       and last_seen_at <= now()) as wau,
    count(*) filter (where last_seen_at >= now() - interval '30 days'
                       and last_seen_at <= now()) as mau
  from public.profiles;

create or replace view analytics.kpis as
  select
    (select count(*) from public.profiles)      as total_users,
    (select count(*) from public.posts)         as total_posts,
    (select count(*) from public.stories)       as total_stories,
    (select count(*) from public.comments)      as total_comments,
    (select count(*) from public.likes)         as total_likes,
    (select count(*) from public.subscriptions) as total_follows,
    (select count(*) from public.referrals)     as total_referrals,
    (select count(*) from public.messages)      as total_messages;

-- 4. Lock the read-only role down and grant ONLY the analytics views.
alter role analytics_ro set default_transaction_read_only = on;
alter role analytics_ro set statement_timeout = '60s';
alter role analytics_ro set idle_in_transaction_session_timeout = '30s';

grant usage on schema analytics to analytics_ro;
grant select on all tables in schema analytics to analytics_ro;
alter default privileges in schema analytics grant select on tables to analytics_ro;

-- analytics_ro must NOT reach base tables directly.
revoke all on all tables in schema public from analytics_ro;

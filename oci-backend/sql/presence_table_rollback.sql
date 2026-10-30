-- Undoes presence_table.sql: the heartbeat writes profiles.last_seen_at again
-- (and is sent to every phone again), and the admin views read it there. The
-- latest times kept aside are copied back first. Only for an emergency.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < presence_table_rollback.sql

begin;

drop trigger if exists zz_profiles_quiet_updates on public.profiles;
drop function if exists public.profiles_quiet_updates();

update public.profiles p
   set last_seen_at = pp.last_seen_at
  from public.profile_presence pp
 where pp.user_id = p.id
   and pp.last_seen_at is distinct from p.last_seen_at;

create or replace view analytics.active_users as
select count(*) filter (where last_seen_at >= now() - interval '1 day') as dau,
       count(*) filter (where last_seen_at >= now() - interval '7 days') as wau,
       count(*) filter (where last_seen_at >= now() - interval '30 days') as mau
  from public.profiles;

create or replace view analytics.users as
select p.id,
    p.username,
    p.avatar_url is not null and p.avatar_url <> ''::text as has_avatar,
    p.bio is not null and p.bio <> ''::text as has_bio,
    p.is_private,
    p.referral_tier,
    extract(year from p.birthday)::integer as birth_year,
    p.push_token is not null and p.push_token <> ''::text as has_push_token,
    p.last_seen_at,
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
     left join auth_credentials c on c.user_id = p.id;

drop table if exists public.profile_presence;

commit;

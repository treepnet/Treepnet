-- The travel globes (the new feed's, Trends' Maps tab's): a post's photo is
-- handed out only once the post's media are uploaded — as every other read
-- of posts has it (feed_post_ids, post_by_id, the phone's own reads). Older
-- app versions created a post before its upload finished, with file:// URLs
-- that only work on the author's phone: to anyone else Trends showed such a
-- post as a broken photo on its pin, which opened onto nothing. The pin
-- stays (the profile globe shows it too), without a photo; the author still
-- gets theirs.
--
-- And the pins come in a set order — posts newest first, then story pins
-- newest first — where 040/041 left it to the planner.
--
-- travel_maps (041) otherwise as it was: the same arguments and columns.

create or replace function public.travel_maps(p_ids text[])
returns table (user_id uuid, regions jsonb, points jsonb)
language sql
stable
security definer
set search_path to 'public'
as $function$
  with me as (
    select auth.uid() as id
  ),
  wanted as (
    select distinct x::uuid as id
      from unnest(p_ids[1:50]) x
     where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ),
  visible as (
    select p.id
      from profiles p
      join wanted w on w.id = p.id
      cross join me
     where me.id is not null
       and (
         p.id = me.id
         or (
           not exists (
             select 1 from blocked_users b
              where (b.blocker_id = me.id and b.blocked_id = p.id)
                 or (b.blocker_id = p.id and b.blocked_id = me.id))
           and (
             not coalesce(p.is_private, false)
             or exists (
               select 1 from subscriptions s
                where s.subscriber_id = me.id
                  and s.subscribed_to_id = p.id
                  and coalesce(s.status, 'accepted') = 'accepted')
           )
         )
       )
  )
  select
    v.id,
    coalesce((
      select jsonb_object_agg(r.region, r.c)
        from (
          select region, sum(c)::int as c
            from (
              select location_region as region, count(*) as c
                from posts
               where posts.user_id = v.id
                 and location_region is not null and location_region <> ''
               group by location_region
              union all
              select region_iso, 1
                from visited_regions
               where visited_regions.user_id = v.id
              union all
              select ls.region_iso, count(*)
                from location_stories ls
                join stories s on s.id = ls.story_id and s.user_id = ls.user_id
               where ls.user_id = v.id
                 and ls.lat is not null and ls.lng is not null
                 and ls.region_iso is not null and ls.region_iso <> ''
               group by ls.region_iso
            ) parts
           group by region
        ) r
    ), '{}'::jsonb) as regions,
    coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'post_id', pt.post_id,
                 'lat', pt.lat,
                 'lng', pt.lng,
                 'name', pt.name,
                 'thumb', pt.thumb)
               order by pt.part, pt.at desc)
        from (
          (select 0 as part, posts.created_at as at,
                  posts.id::text as post_id, location_lat as lat,
                  location_lng as lng, location_name as name,
                  case
                    when coalesce(posts.media, '') like '%file://%'
                         and posts.user_id is distinct from (select id from me)
                      then null
                    else public.post_thumb(posts.media)
                  end as thumb
             from posts
            where posts.user_id = v.id
              and location_lat is not null and location_lng is not null
            order by created_at desc
            limit 1000)
          union all
          (select 1, ls.created_at, null, ls.lat, ls.lng, s.location_name,
                  null::text
             from location_stories ls
             join stories s on s.id = ls.story_id and s.user_id = ls.user_id
            where ls.user_id = v.id
              and ls.lat is not null and ls.lng is not null
            order by ls.created_at desc
            limit 1000)
        ) pt
    ), '[]'::jsonb) as points
  from visible v;
$function$;

revoke all on function public.travel_maps(text[]) from public, anon;
grant execute on function public.travel_maps(text[]) to authenticated;

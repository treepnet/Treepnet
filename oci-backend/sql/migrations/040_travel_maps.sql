-- The travel globes of a few people at once, for the new feed (a prototype,
-- branch prototype/new-feed): each post shows its author's globe facing the
-- post's place. The phone keeps only its user's and followed people's posts,
-- so recommended authors' globes come from here.
--
-- What the profile globe shows of [p_ids]' owners, to whoever asks, by the
-- rule the phone uses (database_client _visibleAuthorSql): their own, or not
-- blocked either way and the profile public or followed (an accepted follow).
-- Per person: the regions coloured (posts' regions, regions marked without a
-- post, story pins' regions — as visitedRegionCountsOf) and the pins (posts'
-- and story pins' spots — visitedPointsOf, storyPointsOf), each post's pin
-- with its post id. Fifty people a call at most, a thousand pins each.
--
-- Only adds a function; nothing the live app uses changes.

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
                 'name', pt.name))
        from (
          (select posts.id::text as post_id, location_lat as lat,
                  location_lng as lng, location_name as name
             from posts
            where posts.user_id = v.id
              and location_lat is not null and location_lng is not null
            order by created_at desc
            limit 1000)
          union all
          (select null, ls.lat, ls.lng, s.location_name
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

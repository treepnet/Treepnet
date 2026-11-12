-- 009 made the feed slower than before (~21 ms a page instead of ~7): its
-- visibility rule was a SQL function, and Postgres can't inline a function
-- that holds a subquery (nor a SECURITY DEFINER or SET one), so the rule ran
-- as a separate call for every post. The rule is two views now, which are
-- always merged into the query; the feed functions read them. Results are the
-- same (009's comparison with feed_post_ids, re-run for this one).
--
-- The views see only what the signed-in user (auth.uid()) may see; they're
-- read inside the SECURITY DEFINER feed functions, and the API roles can't
-- read them (new tables and views are closed since 006).

-- Posts the signed-in user may see: theirs, public accounts', and private
-- accounts' they follow (accepted); no blocks either way; uploaded files only.
create or replace view public.feed_visible_posts as
  select p.id, p.user_id, p.created_at
    from public.posts p
    join public.profiles a on a.id = p.user_id
   where coalesce(p.media, '') not like '%file://%'
     and not exists (select 1 from public.blocked_users b
                      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
                         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid()))
     and (p.user_id = auth.uid()
          or not coalesce(a.is_private, false)
          or exists (select 1 from public.subscriptions s
                      where s.subscriber_id = auth.uid()
                        and s.subscribed_to_id = p.user_id
                        and s.status = 'accepted'));

-- The feed's second part: public accounts the user doesn't follow (or asked
-- to), never their own.
create or replace view public.feed_other_posts as
  select p.id, p.user_id, p.created_at
    from public.posts p
    join public.profiles a on a.id = p.user_id
   where coalesce(p.media, '') not like '%file://%'
     and not exists (select 1 from public.blocked_users b
                      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
                         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid()))
     and p.user_id is distinct from auth.uid()
     and not coalesce(a.is_private, false)
     and not exists (select 1 from public.subscriptions s
                      where s.subscriber_id = auth.uid()
                        and s.subscribed_to_id = p.user_id);

revoke all on table public.feed_visible_posts, public.feed_other_posts
  from public, anon, authenticated;

-- No SET, so it is inlined (it reads no tables).
create or replace function public.post_trend_score(
  p_likes integer, p_comments integer, p_created timestamptz)
returns double precision
language sql
stable
as $$
  select (coalesce(p_likes, 0) + 2 * coalesce(p_comments, 0) + 1)::float8
         / (extract(epoch from now() - p_created) / 86400.0 + 2)
$$;
revoke all on function public.post_trend_score(integer, integer, timestamptz)
  from public, anon, authenticated;

create or replace function public.feed_recent_trending(p_exclude uuid[])
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select array(
    select v.id
      from feed_visible_posts v
      left join post_stats ps on ps.id = v.id
     where v.created_at >= now() - interval '14 days'
       and not (v.id = any (coalesce(p_exclude, '{}')))
     order by post_trend_score(ps.likes_count, ps.comments_count, v.created_at) desc,
              v.created_at desc, v.id)
$$;

create or replace function public.feed_page_ids(
  p_order text, p_limit integer, p_offset integer, p_exclude uuid[])
returns uuid[]
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_recent uuid[];
  v_count integer;
  v_ids uuid[];
begin
  if p_order = 'others' then
    return array(
      select v.id from feed_other_posts v
       where not (v.id = any (coalesce(p_exclude, '{}')))
       order by v.created_at desc, v.id
       limit v_limit offset v_offset);
  elsif p_order is distinct from 'trending' then
    return array(
      select v.id from feed_visible_posts v
       where not (v.id = any (coalesce(p_exclude, '{}')))
       order by v.created_at desc, v.id
       limit v_limit offset v_offset);
  end if;

  v_recent := feed_recent_trending(p_exclude);
  v_count := coalesce(array_length(v_recent, 1), 0);
  v_ids := coalesce(v_recent[v_offset + 1 : v_offset + v_limit], '{}');
  if coalesce(array_length(v_ids, 1), 0) < v_limit then
    v_ids := v_ids || array(
      select v.id
        from post_trend t
        join feed_visible_posts v on v.id = t.post_id
       where v.created_at < now() - interval '14 days'
         and not (v.id = any (coalesce(p_exclude, '{}')))
       order by t.score desc, t.created_at desc, t.post_id
       limit v_limit - coalesce(array_length(v_ids, 1), 0)
      offset greatest(v_offset - v_count, 0));
  end if;
  return v_ids;
end;
$$;

create or replace function public.feed_position(
  p_post uuid, p_order text, p_exclude uuid[] default '{}'::uuid[])
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_created timestamptz;
  v_recent uuid[];
  v_trend post_trend%rowtype;
  v_before integer;
begin
  if p_post = any (coalesce(p_exclude, '{}')) then
    return null;
  end if;

  if p_order = 'others' then
    select created_at into v_created from feed_other_posts where id = p_post;
    if not found then
      return null;
    end if;
    select count(*) into v_before
      from feed_other_posts v
     where (v.created_at > v_created or (v.created_at = v_created and v.id < p_post))
       and not (v.id = any (coalesce(p_exclude, '{}')));
    return v_before;
  end if;

  select created_at into v_created from feed_visible_posts where id = p_post;
  if not found then
    return null;
  end if;

  if p_order is distinct from 'trending' then
    select count(*) into v_before
      from feed_visible_posts v
     where (v.created_at > v_created or (v.created_at = v_created and v.id < p_post))
       and not (v.id = any (coalesce(p_exclude, '{}')));
    return v_before;
  end if;

  v_recent := feed_recent_trending(p_exclude);
  if v_created >= now() - interval '14 days' then
    return array_position(v_recent, p_post) - 1;
  end if;
  select * into v_trend from post_trend where post_id = p_post;
  if not found then
    return null;
  end if;
  select count(*) into v_before
    from post_trend t
    join feed_visible_posts v on v.id = t.post_id
   where v.created_at < now() - interval '14 days'
     and (t.score > v_trend.score
          or (t.score = v_trend.score and t.created_at > v_trend.created_at)
          or (t.score = v_trend.score and t.created_at = v_trend.created_at
              and t.post_id < v_trend.post_id))
     and not (v.id = any (coalesce(p_exclude, '{}')));
  return coalesce(array_length(v_recent, 1), 0) + v_before;
end;
$$;

drop function if exists public.feed_post_visible(uuid, uuid, text, boolean, text, uuid[]);

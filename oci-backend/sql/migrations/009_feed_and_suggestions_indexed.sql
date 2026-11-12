-- The feed, Trends and the suggested profiles read only what a page needs.
--
-- feed_posts ranked every post visible to the user on each call (and
-- feed_position on each opened post), then cut the page out, so its time grew
-- with the number of posts toward the API's 5 s limit; posts had no index on
-- created_at at all. suggested_profiles sorted every profile.
--
-- Newest and the feed's "others" part: an index on created_at, and the page
-- taken straight from it, so a page costs about offset + limit rows.
-- Trends: the last 14 days are still scored live (bounded by how much is
-- posted in 14 days); older posts come after them, ordered by a score kept in
-- post_trend and refreshed hourly (refresh_post_trend, crontab.txt), so their
-- order is at most an hour old. The order and the visibility rules are
-- unchanged; feed_post_ids, the old way, stays for comparison.

create index if not exists posts_newest on public.posts (created_at desc, id);
create index if not exists profile_stats_suggested
  on public.profile_stats (followers_count desc, posts_count desc, id);

-- Trends' score: likes plus twice the comments, plus one, divided by the age
-- in days plus two.
create or replace function public.post_trend_score(
  p_likes integer, p_comments integer, p_created timestamptz)
returns double precision
language sql
stable
set search_path = public
as $$
  select (coalesce(p_likes, 0) + 2 * coalesce(p_comments, 0) + 1)::float8
         / (extract(epoch from now() - p_created) / 86400.0 + 2)
$$;

create table if not exists public.post_trend (
  post_id uuid primary key references public.posts (id) on delete cascade,
  score double precision not null,
  created_at timestamptz not null
);
create index if not exists post_trend_order
  on public.post_trend (score desc, created_at desc, post_id);
revoke all on table public.post_trend from public, anon, authenticated;

-- The stored score of every post older than 13 days (a day early, so a post
-- has one before it leaves the live 14-day part).
create or replace function public.refresh_post_trend()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  insert into post_trend (post_id, score, created_at)
  select p.id, post_trend_score(ps.likes_count, ps.comments_count, p.created_at),
         p.created_at
    from posts p
    left join post_stats ps on ps.id = p.id
   where p.created_at < now() - interval '13 days'
  on conflict (post_id) do update
     set score = excluded.score, created_at = excluded.created_at;
  get diagnostics changed = row_count;
  return changed;
end;
$$;
revoke all on function public.refresh_post_trend() from public, anon, authenticated;

-- Whether post [p] (by [p_author], with [p_media]) is in [p_order]'s list for
-- the signed-in user: the same rules feed_post_ids applies.
create or replace function public.feed_post_visible(
  p_id uuid, p_author uuid, p_media text, p_private boolean,
  p_order text, p_exclude uuid[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(p_media, '') not like '%file://%'
     and not (p_id = any (coalesce(p_exclude, '{}')))
     and not exists (select 1 from blocked_users b
                      where (b.blocker_id = auth.uid() and b.blocked_id = p_author)
                         or (b.blocker_id = p_author and b.blocked_id = auth.uid()))
     and case p_order
           when 'others' then
             p_author is distinct from auth.uid()
             and not coalesce(p_private, false)
             and not exists (select 1 from subscriptions s
                              where s.subscriber_id = auth.uid()
                                and s.subscribed_to_id = p_author)
           else
             p_author = auth.uid()
             or not coalesce(p_private, false)
             or exists (select 1 from subscriptions s
                         where s.subscriber_id = auth.uid()
                           and s.subscribed_to_id = p_author
                           and s.status = 'accepted')
         end
$$;
revoke all on function public.feed_post_visible(uuid, uuid, text, boolean, text, uuid[])
  from public, anon, authenticated;

-- Trends' live part: the last 14 days, in order.
create or replace function public.feed_recent_trending(p_exclude uuid[])
returns uuid[]
language sql
stable
security definer
set search_path = public
as $$
  select array(
    select p.id
      from posts p
      join profiles a on a.id = p.user_id
      left join post_stats ps on ps.id = p.id
     where p.created_at >= now() - interval '14 days'
       and feed_post_visible(p.id, p.user_id, p.media, a.is_private, 'trending', p_exclude)
     order by post_trend_score(ps.likes_count, ps.comments_count, p.created_at) desc,
              p.created_at desc, p.id)
$$;
revoke all on function public.feed_recent_trending(uuid[]) from public, anon, authenticated;

-- One page of [p_order] (newest | others | trending), as post ids.
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
  if p_order is distinct from 'trending' then
    return array(
      select p.id
        from posts p
        join profiles a on a.id = p.user_id
       where feed_post_visible(p.id, p.user_id, p.media, a.is_private, p_order, p_exclude)
       order by p.created_at desc, p.id
       limit v_limit offset v_offset);
  end if;

  v_recent := feed_recent_trending(p_exclude);
  v_count := coalesce(array_length(v_recent, 1), 0);
  v_ids := coalesce(v_recent[v_offset + 1 : v_offset + v_limit], '{}');
  if coalesce(array_length(v_ids, 1), 0) < v_limit then
    v_ids := v_ids || array(
      select p.id
        from post_trend t
        join posts p on p.id = t.post_id
        join profiles a on a.id = p.user_id
       where p.created_at < now() - interval '14 days'
         and feed_post_visible(p.id, p.user_id, p.media, a.is_private, 'trending', p_exclude)
       order by t.score desc, t.created_at desc, t.post_id
       limit v_limit - coalesce(array_length(v_ids, 1), 0)
      offset greatest(v_offset - v_count, 0));
  end if;
  return v_ids;
end;
$$;
revoke all on function public.feed_page_ids(text, integer, integer, uuid[])
  from public, anon, authenticated;

create or replace function public.feed_posts(
  p_order text, p_limit integer default 20, p_offset integer default 0,
  p_exclude uuid[] default '{}'::uuid[])
returns setof feed_post
language sql
stable
security definer
set search_path = public
as $$
  select * from feed_post_rows(feed_page_ids(p_order, p_limit, p_offset, p_exclude))
$$;

-- Where [p_post] is in [p_order]'s list (0-based), or null when it isn't.
create or replace function public.feed_position(
  p_post uuid, p_order text, p_exclude uuid[] default '{}'::uuid[])
returns integer
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_post posts%rowtype;
  v_private boolean;
  v_recent uuid[];
  v_trend post_trend%rowtype;
  v_before integer;
begin
  select * into v_post from posts where id = p_post;
  if not found then
    return null;
  end if;
  select is_private into v_private from profiles where id = v_post.user_id;
  if not found
     or not feed_post_visible(v_post.id, v_post.user_id, v_post.media, v_private,
                              p_order, p_exclude) then
    return null;
  end if;

  if p_order is distinct from 'trending' then
    select count(*) into v_before
      from posts p
      join profiles a on a.id = p.user_id
     where (p.created_at > v_post.created_at
            or (p.created_at = v_post.created_at and p.id < v_post.id))
       and feed_post_visible(p.id, p.user_id, p.media, a.is_private, p_order, p_exclude);
    return v_before;
  end if;

  v_recent := feed_recent_trending(p_exclude);
  if v_post.created_at >= now() - interval '14 days' then
    return array_position(v_recent, p_post) - 1;
  end if;
  select * into v_trend from post_trend where post_id = p_post;
  if not found then
    return null;
  end if;
  select count(*) into v_before
    from post_trend t
    join posts p on p.id = t.post_id
    join profiles a on a.id = p.user_id
   where p.created_at < now() - interval '14 days'
     and (t.score > v_trend.score
          or (t.score = v_trend.score and t.created_at > v_trend.created_at)
          or (t.score = v_trend.score and t.created_at = v_trend.created_at
              and t.post_id < v_trend.post_id))
     and feed_post_visible(p.id, p.user_id, p.media, a.is_private, 'trending', p_exclude);
  return coalesce(array_length(v_recent, 1), 0) + v_before;
end;
$$;

create or replace function public.suggested_profiles(p_limit integer default 50)
returns table(id uuid, username text, full_name text, avatar_url text, bio text,
              is_private boolean)
language sql
stable
security definer
set search_path = public
as $$
  -- From the stats index: every profile has its profile_stats row (made with
  -- the profile), so the first matching rows are the page.
  select a.id, a.username, a.full_name, a.avatar_url, a.bio, a.is_private
    from profile_stats st
    join profiles a on a.id = st.id
   where a.id is distinct from auth.uid()
     and a.username is not null
     and not exists (select 1 from subscriptions s
                      where s.subscriber_id = auth.uid()
                        and s.subscribed_to_id = a.id)
     and not blocked_between(auth.uid(), a.id)
   order by st.followers_count desc, st.posts_count desc, st.id
   limit least(greatest(coalesce(p_limit, 50), 1), 100)
$$;

select refresh_post_trend();

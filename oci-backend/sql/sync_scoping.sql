-- What phones sync, step 1 of 2: everything the narrower sync needs, added
-- next to what is there. Nothing an older app reads changes.
--
-- Until now every phone synced every profile, post, like, comment, story,
-- follow and visited region of every user (sync-config.yaml's global
-- buckets) and worked counts, notifications and lists out from them. The new
-- sync (sync-config.yaml, step 2) brings a phone only its own data and that
-- of the people it follows, plus the profile or post open on screen. So the
-- server now keeps what used to be counted on the phone:
--
--   * post_stats      likes and comments per post;
--   * profile_stats   posts, located posts, followers and followings per
--                     profile;
--   * comments        who wrote them (name, username, avatar), the post's
--                     author, likes and whether the post's author liked it;
--   * notifications   one row per like, comment, follow and follow request
--                     on your things, with the actor's name and avatar and
--                     the post's thumbnail — the newest 300 per person;
--   * story_highlight_items.user_id   the highlight's owner, so a highlight's
--                     stories sync with the rest of that person's things.
--
-- All of it is kept by triggers and filled in here from what exists. And the
-- lists that span everyone come from the server, with privacy and blocks
-- checked there: feed_posts (the rest of the feed, Trends, the newest posts),
-- feed_position, post_by_id, saved_posts_page, post_likers,
-- post_likers_in_followings, follow_list, suggested_profiles, profile_cards
-- and story_by_id.
--
-- Rollback: sync_scoping_rollback.sql.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet -v ON_ERROR_STOP=1 < sync_scoping.sql

begin;

-- ---------------------------------------------------------------------------
-- Who may see a person's things: themselves, or anyone neither blocked by
-- nor blocking them, if the account is public or they follow it.

create or replace function public.can_view_author(p_author uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_author = auth.uid()
      or (not public.blocked_between(auth.uid(), p_author)
          and (not coalesce((select p.is_private from public.profiles p
                              where p.id = p_author), false)
               or exists (select 1 from public.subscriptions s
                           where s.subscriber_id = auth.uid()
                             and s.subscribed_to_id = p_author
                             and s.status = 'accepted')))
$$;

-- The picture a notification shows for a post: a video's first frame, else
-- the photo's thumbnail, else the photo.
create or replace function public.post_thumb(p_media text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  first jsonb;
begin
  first := p_media::jsonb -> 0;
  if first ->> 'type' = '__video_media__' then
    return first ->> 'first_frame_url';
  end if;
  return coalesce(first ->> 'thumb_url', first ->> 'url');
exception when others then
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Counts.

create table if not exists public.post_stats (
  id uuid primary key references public.posts(id) on delete cascade,
  user_id uuid not null,
  likes_count integer not null default 0,
  comments_count integer not null default 0
);

create table if not exists public.profile_stats (
  id uuid primary key references public.profiles(id) on delete cascade,
  posts_count integer not null default 0,
  places_count integer not null default 0,
  followers_count integer not null default 0,
  following_count integer not null default 0
);

insert into public.profile_stats (id) select id from public.profiles
on conflict (id) do nothing;

insert into public.post_stats (id, user_id) select id, user_id from public.posts
on conflict (id) do nothing;

update public.post_stats ps set
  likes_count = (select count(*) from public.likes l where l.post_id = ps.id),
  comments_count = (select count(*) from public.comments c where c.post_id = ps.id);

update public.profile_stats st set
  posts_count = (select count(*) from public.posts p where p.user_id = st.id),
  places_count = (select count(*) from public.posts p
                   where p.user_id = st.id and p.location_lat is not null),
  followers_count = (select count(*) from public.subscriptions s
                      where s.subscribed_to_id = st.id and s.status = 'accepted'),
  following_count = (select count(*) from public.subscriptions s
                      where s.subscriber_id = st.id and s.status = 'accepted');

-- ---------------------------------------------------------------------------
-- Comments carry their author's card, the post's author and their likes, so a
-- post's comments sync on their own (no profile of every commenter).

alter table public.comments
  add column if not exists post_owner_id uuid,
  add column if not exists author_username text,
  add column if not exists author_full_name text,
  add column if not exists author_avatar_url text,
  add column if not exists likes_count integer not null default 0,
  add column if not exists liked_by_author boolean not null default false;

update public.comments c set
  post_owner_id = p.user_id
from public.posts p
where p.id = c.post_id;

update public.comments c set
  author_username = pr.username,
  author_full_name = pr.full_name,
  author_avatar_url = pr.avatar_url
from public.profiles pr
where pr.id = c.user_id;

update public.comments c set
  likes_count = (select count(*) from public.likes l where l.comment_id = c.id),
  liked_by_author = exists (select 1 from public.likes l
                             where l.comment_id = c.id
                               and l.user_id = c.post_owner_id);

create index if not exists comments_post_owner_idx
  on public.comments (post_id, post_owner_id);

-- A highlight's stories carry its owner.
alter table public.story_highlight_items add column if not exists user_id uuid;

update public.story_highlight_items i set user_id = h.user_id
from public.story_highlights h
where h.id = i.highlight_id;

create index if not exists story_highlight_items_user_idx
  on public.story_highlight_items (user_id);

-- ---------------------------------------------------------------------------
-- Notifications: likes and comments on your posts, follows and requests.

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  type text not null
    check (type in ('like', 'comment', 'follow', 'follow_request')),
  -- The like, comment or follow it is about; it goes when that does.
  source_id uuid not null unique,
  post_id uuid references public.posts(id) on delete cascade,
  content text,
  post_thumb text,
  actor_username text,
  actor_full_name text,
  actor_avatar_url text,
  created_at timestamptz not null default now()
);

create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);
create index if not exists notifications_actor_idx
  on public.notifications (actor_id);

-- How many each person keeps.
create or replace function public.notifications_keep()
returns integer
language sql
immutable
as $$ select 300 $$;

insert into public.notifications
  (recipient_id, actor_id, type, source_id, post_id, content, post_thumb,
   actor_username, actor_full_name, actor_avatar_url, created_at)
select p.user_id, l.user_id, 'like', l.id, l.post_id, null,
       public.post_thumb(p.media), a.username, a.full_name, a.avatar_url,
       l.created_at
  from public.likes l
  join public.posts p on p.id = l.post_id
  join public.profiles a on a.id = l.user_id
 where l.user_id <> p.user_id
union all
select p.user_id, c.user_id, 'comment', c.id, c.post_id, left(c.content, 300),
       public.post_thumb(p.media), a.username, a.full_name, a.avatar_url,
       c.created_at
  from public.comments c
  join public.posts p on p.id = c.post_id
  join public.profiles a on a.id = c.user_id
 where c.user_id <> p.user_id
union all
select s.subscribed_to_id, s.subscriber_id,
       case when s.status = 'pending' then 'follow_request' else 'follow' end,
       s.id, null, null, null, a.username, a.full_name, a.avatar_url,
       s.created_at
  from public.subscriptions s
  join public.profiles a on a.id = s.subscriber_id
 where s.subscriber_id <> s.subscribed_to_id
on conflict (source_id) do nothing;

delete from public.notifications n
 using (select id, row_number() over (partition by recipient_id
                                      order by created_at desc) as rn
          from public.notifications) ranked
 where ranked.id = n.id and ranked.rn > public.notifications_keep();

-- ---------------------------------------------------------------------------
-- Triggers. Each is security definer: it writes rows the acting user may not.

create or replace function public.sync_scoping_on_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into profile_stats (id) values (new.id) on conflict (id) do nothing;
    return null;
  end if;
  if new.username is distinct from old.username
     or new.full_name is distinct from old.full_name
     or new.avatar_url is distinct from old.avatar_url then
    update comments set author_username = new.username,
                        author_full_name = new.full_name,
                        author_avatar_url = new.avatar_url
     where user_id = new.id;
    update notifications set actor_username = new.username,
                             actor_full_name = new.full_name,
                             actor_avatar_url = new.avatar_url
     where actor_id = new.id;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_scoping_on_profile on public.profiles;
create trigger sync_scoping_on_profile
  after insert or update of username, full_name, avatar_url on public.profiles
  for each row execute function public.sync_scoping_on_profile();

create or replace function public.sync_scoping_on_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into post_stats (id, user_id) values (new.id, new.user_id)
    on conflict (id) do nothing;
    update profile_stats
       set posts_count = posts_count + 1,
           places_count = places_count
             + case when new.location_lat is not null then 1 else 0 end
     where id = new.user_id;
  elsif tg_op = 'DELETE' then
    update profile_stats
       set posts_count = greatest(posts_count - 1, 0),
           places_count = greatest(places_count
             - case when old.location_lat is not null then 1 else 0 end, 0)
     where id = old.user_id;
  else
    if (new.location_lat is null) is distinct from (old.location_lat is null) then
      update profile_stats
         set places_count = greatest(places_count
               + case when new.location_lat is not null then 1 else -1 end, 0)
       where id = new.user_id;
    end if;
    if new.media is distinct from old.media then
      update notifications set post_thumb = post_thumb(new.media)
       where post_id = new.id;
    end if;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_scoping_on_post on public.posts;
create trigger sync_scoping_on_post
  after insert or delete or update of location_lat, media on public.posts
  for each row execute function public.sync_scoping_on_post();

-- A comment's own columns are the server's: filled in on the way in, and an
-- update from the app (not from a trigger) can only change the text.
create or replace function public.comments_fill()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    select p.user_id into new.post_owner_id from posts p where p.id = new.post_id;
    select pr.username, pr.full_name, pr.avatar_url
      into new.author_username, new.author_full_name, new.author_avatar_url
      from profiles pr where pr.id = new.user_id;
    new.likes_count := 0;
    new.liked_by_author := false;
  elsif pg_trigger_depth() = 1 then
    new.post_owner_id := old.post_owner_id;
    new.author_username := old.author_username;
    new.author_full_name := old.author_full_name;
    new.author_avatar_url := old.author_avatar_url;
    new.likes_count := old.likes_count;
    new.liked_by_author := old.liked_by_author;
  end if;
  return new;
end;
$$;

drop trigger if exists comments_fill on public.comments;
create trigger comments_fill
  before insert or update on public.comments
  for each row execute function public.comments_fill();

create or replace function public.sync_scoping_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post posts%rowtype;
begin
  if tg_op = 'INSERT' then
    update post_stats set comments_count = comments_count + 1
     where id = new.post_id;
    select * into v_post from posts where id = new.post_id;
    if found and new.user_id <> v_post.user_id then
      insert into notifications
        (recipient_id, actor_id, type, source_id, post_id, content, post_thumb,
         actor_username, actor_full_name, actor_avatar_url, created_at)
      values
        (v_post.user_id, new.user_id, 'comment', new.id, new.post_id,
         left(new.content, 300), post_thumb(v_post.media),
         new.author_username, new.author_full_name, new.author_avatar_url,
         new.created_at)
      on conflict (source_id) do nothing;
      perform notifications_prune(v_post.user_id);
    end if;
  else
    update post_stats set comments_count = greatest(comments_count - 1, 0)
     where id = old.post_id;
    delete from notifications where source_id = old.id;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_scoping_on_comment on public.comments;
create trigger sync_scoping_on_comment
  after insert or delete on public.comments
  for each row execute function public.sync_scoping_on_comment();

create or replace function public.sync_scoping_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post posts%rowtype;
  v_like likes%rowtype;
  v_delta integer;
begin
  if tg_op = 'INSERT' then
    v_like := new;
    v_delta := 1;
  else
    v_like := old;
    v_delta := -1;
  end if;

  if v_like.post_id is not null then
    update post_stats set likes_count = greatest(likes_count + v_delta, 0)
     where id = v_like.post_id;
    if tg_op = 'INSERT' then
      select * into v_post from posts where id = v_like.post_id;
      if found and v_like.user_id <> v_post.user_id then
        insert into notifications
          (recipient_id, actor_id, type, source_id, post_id, post_thumb,
           actor_username, actor_full_name, actor_avatar_url, created_at)
        select v_post.user_id, v_like.user_id, 'like', v_like.id, v_like.post_id,
               post_thumb(v_post.media), a.username, a.full_name, a.avatar_url,
               v_like.created_at
          from profiles a where a.id = v_like.user_id
        on conflict (source_id) do nothing;
        perform notifications_prune(v_post.user_id);
      end if;
    else
      delete from notifications where source_id = v_like.id;
    end if;
  elsif v_like.comment_id is not null then
    update comments c
       set likes_count = greatest(c.likes_count + v_delta, 0),
           liked_by_author = case
             when v_like.user_id = c.post_owner_id then tg_op = 'INSERT'
             else c.liked_by_author
           end
     where c.id = v_like.comment_id;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_scoping_on_like on public.likes;
create trigger sync_scoping_on_like
  after insert or delete on public.likes
  for each row execute function public.sync_scoping_on_like();

create or replace function public.sync_scoping_on_subscription()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  was_accepted boolean := tg_op <> 'INSERT' and old.status = 'accepted';
  is_accepted boolean := tg_op <> 'DELETE' and new.status = 'accepted';
  v_sub subscriptions%rowtype;
  v_delta integer;
begin
  if tg_op = 'DELETE' then v_sub := old; else v_sub := new; end if;

  v_delta := (case when is_accepted then 1 else 0 end)
           - (case when was_accepted then 1 else 0 end);
  if v_delta <> 0 then
    update profile_stats set followers_count = greatest(followers_count + v_delta, 0)
     where id = v_sub.subscribed_to_id;
    update profile_stats set following_count = greatest(following_count + v_delta, 0)
     where id = v_sub.subscriber_id;
  end if;

  if tg_op = 'DELETE' then
    delete from notifications where source_id = old.id;
  elsif tg_op = 'INSERT' then
    if new.subscriber_id <> new.subscribed_to_id then
      insert into notifications
        (recipient_id, actor_id, type, source_id, actor_username,
         actor_full_name, actor_avatar_url, created_at)
      select new.subscribed_to_id, new.subscriber_id,
             case when new.status = 'pending' then 'follow_request' else 'follow' end,
             new.id, a.username, a.full_name, a.avatar_url, new.created_at
        from profiles a where a.id = new.subscriber_id
      on conflict (source_id) do nothing;
      perform notifications_prune(new.subscribed_to_id);
    end if;
  elsif new.status is distinct from old.status then
    update notifications
       set type = case when new.status = 'pending' then 'follow_request'
                       else 'follow' end
     where source_id = new.id;
  end if;
  return null;
end;
$$;

drop trigger if exists sync_scoping_on_subscription on public.subscriptions;
create trigger sync_scoping_on_subscription
  after insert or delete or update of status on public.subscriptions
  for each row execute function public.sync_scoping_on_subscription();

create or replace function public.notifications_prune(p_recipient uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from notifications
   where id in (select id from notifications
                 where recipient_id = p_recipient
                 order by created_at desc
                offset notifications_keep());
$$;

create or replace function public.story_highlight_items_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select h.user_id into new.user_id from story_highlights h
   where h.id = new.highlight_id;
  return new;
end;
$$;

drop trigger if exists story_highlight_items_owner on public.story_highlight_items;
create trigger story_highlight_items_owner
  before insert or update on public.story_highlight_items
  for each row execute function public.story_highlight_items_owner();

-- ---------------------------------------------------------------------------
-- Access. The new tables are read through sync (as the powersync role, which
-- bypasses row security) and through the functions below; the app never
-- writes them.

alter table public.post_stats enable row level security;
alter table public.profile_stats enable row level security;
alter table public.notifications enable row level security;

drop policy if exists post_stats_select on public.post_stats;
create policy post_stats_select on public.post_stats
  for select using (public.can_view_author(user_id));
drop policy if exists profile_stats_select on public.profile_stats;
create policy profile_stats_select on public.profile_stats
  for select using (true);
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications
  for select using (auth.uid() = recipient_id);

revoke all on public.post_stats, public.profile_stats, public.notifications
  from public, anon, authenticated;
grant select on public.post_stats, public.profile_stats, public.notifications
  to authenticated;

-- The powersync publication is FOR ALL TABLES, so the new tables replicate
-- without being added to it.

-- ---------------------------------------------------------------------------
-- Lists that span everyone. Each checks who may see what, here.

-- A post as the app shows it: the row, its author's card, counts, and
-- whether the caller liked it.
-- (cascade: a rerun drops the functions returning it; they follow below)
drop type if exists public.feed_post cascade;
drop function if exists public.feed_post_ids(text);
drop function if exists public.feed_position(uuid, text);
create type public.feed_post as (
  id uuid,
  user_id uuid,
  caption text,
  media text,
  created_at timestamptz,
  updated_at timestamptz,
  location text,
  location_country text,
  location_region text,
  location_name text,
  location_lat double precision,
  location_lng double precision,
  username text,
  full_name text,
  avatar_url text,
  referral_tier integer,
  referral_tier_expires_at timestamptz,
  likes_count integer,
  comments_count integer,
  liked_by_me boolean,
  author_places integer
);

create or replace function public.feed_post_rows(p_ids uuid[])
returns setof public.feed_post
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.user_id, p.caption, p.media, p.created_at, p.updated_at,
         p.location, p.location_country, p.location_region, p.location_name,
         p.location_lat, p.location_lng,
         a.username, a.full_name, a.avatar_url, a.referral_tier,
         a.referral_tier_expires_at,
         coalesce(ps.likes_count, 0), coalesce(ps.comments_count, 0),
         exists (select 1 from likes l
                  where l.post_id = p.id and l.user_id = auth.uid()),
         coalesce(st.places_count, 0)
    from unnest(p_ids) with ordinality as wanted(id, n)
    join posts p on p.id = wanted.id
    join profiles a on a.id = p.user_id
    left join post_stats ps on ps.id = p.id
    left join profile_stats st on st.id = p.user_id
   order by wanted.n
$$;

-- The ids of [p_order]'s list, in order, without [p_exclude] (the posts the
-- caller hid on their phone):
--   newest    every post the caller may see, newest first;
--   others    public accounts' posts the caller doesn't follow, newest first
--             (the feed after the people they follow);
--   trending  the last 14 days first, then the rest; each by likes plus twice
--             the comments, plus one, over the age in days plus two.
create or replace function public.feed_post_ids(p_order text, p_exclude uuid[])
returns table (id uuid)
language sql
stable
security definer
set search_path = public
as $$
  select p.id
    from posts p
    join profiles a on a.id = p.user_id
    left join post_stats ps on ps.id = p.id
   where coalesce(p.media, '') not like '%file://%'
     and not (p.id = any (coalesce(p_exclude, '{}')))
     and not exists (select 1 from blocked_users b
                      where (b.blocker_id = auth.uid() and b.blocked_id = p.user_id)
                         or (b.blocker_id = p.user_id and b.blocked_id = auth.uid()))
     and case p_order
           when 'others' then
             p.user_id is distinct from auth.uid()
             and not coalesce(a.is_private, false)
             and not exists (select 1 from subscriptions s
                              where s.subscriber_id = auth.uid()
                                and s.subscribed_to_id = p.user_id)
           else
             p.user_id = auth.uid()
             or not coalesce(a.is_private, false)
             or exists (select 1 from subscriptions s
                         where s.subscriber_id = auth.uid()
                           and s.subscribed_to_id = p.user_id
                           and s.status = 'accepted')
         end
   order by
     case when p_order = 'trending' then
       case when p.created_at >= now() - interval '14 days' then 0 else 1 end
     end,
     case when p_order = 'trending' then
       (coalesce(ps.likes_count, 0) + 2 * coalesce(ps.comments_count, 0) + 1)::float8
       / (extract(epoch from now() - p.created_at) / 86400.0 + 2)
     end desc,
     p.created_at desc,
     p.id
$$;

create or replace function public.feed_posts(
  p_order text,
  p_limit integer default 20,
  p_offset integer default 0,
  p_exclude uuid[] default '{}'
)
returns setof public.feed_post
language sql
stable
security definer
set search_path = public
as $$
  select * from feed_post_rows(array(
    select ids.id from feed_post_ids(p_order, p_exclude)
           with ordinality as ids(id, n)
     order by ids.n
     limit least(greatest(coalesce(p_limit, 20), 1), 100)
    offset greatest(coalesce(p_offset, 0), 0)
  ))
$$;

-- Where [p_post] is in [p_order]'s list (its offset), or null.
create or replace function public.feed_position(
  p_post uuid,
  p_order text,
  p_exclude uuid[] default '{}'
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select (ids.n - 1)::integer
    from feed_post_ids(p_order, p_exclude) with ordinality as ids(id, n)
   where ids.id = p_post
$$;

create or replace function public.post_by_id(p_id uuid)
returns setof public.feed_post
language sql
stable
security definer
set search_path = public
as $$
  select r.* from feed_post_rows(array[p_id]) r
   where can_view_author(r.user_id)
     and coalesce(r.media, '') not like '%file://%'
$$;

create or replace function public.saved_posts_page(
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.feed_post
language sql
stable
security definer
set search_path = public
as $$
  select * from feed_post_rows(array(
    select sp.post_id
      from saved_posts sp
      join posts p on p.id = sp.post_id
     where sp.user_id = auth.uid() and can_view_author(p.user_id)
     order by sp.created_at desc
     limit least(greatest(coalesce(p_limit, 20), 1), 100)
    offset greatest(coalesce(p_offset, 0), 0)
  ))
$$;

-- People who liked a post the caller may see, newest like first.
create or replace function public.post_likers(
  p_post uuid,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (id uuid, username text, full_name text, avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.username, a.full_name, a.avatar_url
    from likes l
    join posts p on p.id = l.post_id
    join profiles a on a.id = l.user_id
   where l.post_id = p_post
     and can_view_author(p.user_id)
     and not blocked_between(auth.uid(), a.id)
   order by l.created_at desc, a.id
   limit least(greatest(coalesce(p_limit, 30), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

-- For each of [p_posts], up to [p_per_post] people the caller follows who
-- liked it ("liked by …").
create or replace function public.post_likers_in_followings(
  p_posts uuid[],
  p_per_post integer default 3
)
returns table (post_id uuid, id uuid, username text, full_name text,
               avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
  select ranked.post_id, ranked.id, ranked.username, ranked.full_name,
         ranked.avatar_url
    from (
      select l.post_id, a.id, a.username, a.full_name, a.avatar_url,
             row_number() over (partition by l.post_id
                                order by l.created_at desc) as n
        from likes l
        join posts p on p.id = l.post_id
        join profiles a on a.id = l.user_id
        join subscriptions s on s.subscribed_to_id = l.user_id
                            and s.subscriber_id = auth.uid()
                            and s.status = 'accepted'
       where l.post_id = any (p_posts[1:100])
         and l.user_id <> auth.uid()
         and can_view_author(p.user_id)
         and not blocked_between(auth.uid(), a.id)
    ) ranked
   where ranked.n <= least(greatest(coalesce(p_per_post, 3), 1), 10)
$$;

-- [p_user]'s followers ([p_followers]) or followings, newest follow first. A
-- private account's lists only show to its followers.
create or replace function public.follow_list(
  p_user uuid,
  p_followers boolean,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (id uuid, username text, full_name text, avatar_url text,
               bio text, is_private boolean)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.username, a.full_name, a.avatar_url, a.bio, a.is_private
    from subscriptions s
    join profiles a on a.id = case when p_followers then s.subscriber_id
                                   else s.subscribed_to_id end
   where (case when p_followers then s.subscribed_to_id
               else s.subscriber_id end) = p_user
     and s.status = 'accepted'
     and can_view_author(p_user)
     and not blocked_between(auth.uid(), a.id)
   order by s.created_at desc, a.id
   limit least(greatest(coalesce(p_limit, 30), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

-- People to follow: not the caller, not followed or asked yet, no block
-- either way; the most followed first.
create or replace function public.suggested_profiles(p_limit integer default 50)
returns table (id uuid, username text, full_name text, avatar_url text,
               bio text, is_private boolean)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.username, a.full_name, a.avatar_url, a.bio, a.is_private
    from profiles a
    left join profile_stats st on st.id = a.id
   where a.id is distinct from auth.uid()
     and a.username is not null
     and not exists (select 1 from subscriptions s
                      where s.subscriber_id = auth.uid()
                        and s.subscribed_to_id = a.id)
     and not blocked_between(auth.uid(), a.id)
   order by coalesce(st.followers_count, 0) desc,
            coalesce(st.posts_count, 0) desc, a.id
   limit least(greatest(coalesce(p_limit, 50), 1), 100)
$$;

-- Name, username and avatar of each of [p_ids] (chat and other screens that
-- show people the phone has no profile of).
create or replace function public.profile_cards(p_ids uuid[])
returns table (id uuid, username text, full_name text, avatar_url text,
               referral_tier integer, referral_tier_expires_at timestamptz,
               is_private boolean)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.username, a.full_name, a.avatar_url, a.referral_tier,
         a.referral_tier_expires_at, a.is_private
    from profiles a
   where a.id = any (p_ids[1:200])
$$;

-- A story with its author's card, when the caller may see it (a shared story
-- in chat, say). Expired ones too, as long as they are public.
create or replace function public.story_by_id(p_id uuid)
returns table (id uuid, user_id uuid, content_type text, content_url text,
               duration integer, created_at timestamptz,
               expires_at timestamptz, location_name text,
               location_lat double precision, location_lng double precision,
               username text, full_name text, avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
  select s.id, s.user_id, s.content_type::text, s.content_url, s.duration,
         s.created_at, s.expires_at, s.location_name, s.location_lat,
         s.location_lng, a.username, a.full_name, a.avatar_url
    from stories s
    join profiles a on a.id = s.user_id
   where s.id = p_id
     and (s.visibility = 'public' or s.user_id = auth.uid())
     and can_view_author(s.user_id)
$$;

-- Row policies call it as the signed-in user.
revoke all on function public.can_view_author(uuid) from public, anon;
grant execute on function public.can_view_author(uuid) to authenticated;
revoke all on function public.post_thumb(text) from public, anon, authenticated;
revoke all on function public.notifications_keep() from public, anon, authenticated;
revoke all on function public.notifications_prune(uuid) from public, anon, authenticated;
revoke all on function public.feed_post_rows(uuid[]) from public, anon, authenticated;
revoke all on function public.feed_post_ids(text, uuid[]) from public, anon, authenticated;
revoke all on function public.sync_scoping_on_profile() from public, anon, authenticated;
revoke all on function public.sync_scoping_on_post() from public, anon, authenticated;
revoke all on function public.sync_scoping_on_comment() from public, anon, authenticated;
revoke all on function public.sync_scoping_on_like() from public, anon, authenticated;
revoke all on function public.sync_scoping_on_subscription() from public, anon, authenticated;
revoke all on function public.comments_fill() from public, anon, authenticated;
revoke all on function public.story_highlight_items_owner() from public, anon, authenticated;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.feed_posts(text, integer, integer, uuid[])',
    'public.feed_position(uuid, text, uuid[])',
    'public.post_by_id(uuid)',
    'public.saved_posts_page(integer, integer)',
    'public.post_likers(uuid, integer, integer)',
    'public.post_likers_in_followings(uuid[], integer)',
    'public.follow_list(uuid, boolean, integer, integer)',
    'public.suggested_profiles(integer)',
    'public.profile_cards(uuid[])',
    'public.story_by_id(uuid)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

commit;

-- PostgREST picks up the new functions.
notify pgrst, 'reload schema';

-- The treepnet database's schema as production had it on 2026-11-01: every
-- table, view, function, trigger, policy, index and grant, no data. The start
-- of the migration history (sql/migrate.sh); every change after it is a
-- numbered file in this folder.
--
-- Until then changes were applied by hand from the loose files in sql/ (and
-- a few from nowhere in the repo: auth_credentials, auth_codes), in no
-- recorded order — this is what they added up to.
--
-- Made with: pg_dump --schema-only --no-owner --no-publications
-- --no-subscriptions (the powersync publication comes from
-- postgres/initdb/01-powersync.sh). On a new server: create the roles first
-- (postgres/initdb, sql/setup-roles.sql: authenticator, authenticated, anon,
-- powersync, analytics_ro, chat_blocks_ro), then run sql/migrate.sh.
-- On production it was recorded without running (migrate.sh --mark-applied).

--
-- PostgreSQL database dump
--


-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Debian 16.15-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: analytics; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA analytics;


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: attachment_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.attachment_type AS ENUM (
    'image',
    'file',
    'video',
    'giphy',
    'audio',
    'url_preview'
);


--
-- Name: conversation_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversation_type AS ENUM (
    'one-on-one',
    'group'
);


--
-- Name: feed_post; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.feed_post AS (
	id uuid,
	user_id uuid,
	caption text,
	media text,
	created_at timestamp with time zone,
	updated_at timestamp with time zone,
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
	referral_tier_expires_at timestamp with time zone,
	likes_count integer,
	comments_count integer,
	liked_by_me boolean,
	author_places integer
);


--
-- Name: media_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.media_type AS ENUM (
    'photo',
    'video'
);


--
-- Name: message_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.message_type AS ENUM (
    'text',
    'image',
    'video',
    'voice'
);


--
-- Name: story_content_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.story_content_type AS ENUM (
    'image',
    'video'
);


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $_$
  SELECT v::uuid FROM (
    SELECT coalesce(
             nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'oid',
             nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
           ) AS v
  ) t
  -- Da'vo UUID shaklida bo'lmasa xato o'rniga NULL qaytsin.
  WHERE v ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$_$;


--
-- Name: blocked_between(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.blocked_between(a uuid, b uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from blocked_users
     where (blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a)
  )
$$;


--
-- Name: can_view_author(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_author(p_author uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p_author = auth.uid()
      or (not public.blocked_between(auth.uid(), p_author)
          and (not coalesce((select p.is_private from public.profiles p
                              where p.id = p_author), false)
               or exists (select 1 from public.subscriptions s
                           where s.subscriber_id = auth.uid()
                             and s.subscribed_to_id = p_author
                             and s.status = 'accepted')))
$$;


--
-- Name: chat_profile_card(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.chat_profile_card(p_id uuid) RETURNS TABLE(username text, avatar_url text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select p.username, p.avatar_url from profiles p where p.id = p_id
$$;


--
-- Name: clear_posts_objects(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_posts_objects() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Direct deletion from storage.objects is not allowed by Supabase's protect_delete trigger.
  return null;
end;
$$;


--
-- Name: clear_stories_objects(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.clear_stories_objects() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  -- Direct deletion from storage.objects is not allowed by Supabase's protect_delete trigger.
  return null;
end;
$$;


--
-- Name: comments_fill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.comments_fill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: delete_account(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_account() RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  -- JWT sub (the profile id). RLS uses the same rule: auth.uid() = sub.
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;
  perform public.delete_account_by_id(v_uid);
end;
$$;


--
-- Name: delete_account_by_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_account_by_id(p_uid uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_email text;
  v_media text[];
begin
  if p_uid is null then
    raise exception 'missing user id';
  end if;

  select lower(email) into v_email from profiles where id = p_uid;

  -- Media files to delete once the rows are gone. Post media is a JSON string;
  -- the URLs are matched as text so a malformed value can't block a deletion.
  -- (Greedy quantifiers only: in Postgres the first quantifier sets the whole
  -- pattern's greediness, and [^"] already stops each match at the quote.)
  -- A URL is either the bucket's own or the media.treepnet.com CDN in front of
  -- it (media_cdn_urls.sql).
  select coalesce(array_agg(distinct u), '{}') into v_media
    from (
      select (regexp_matches(media, 'https://(?:objectstorage\.[^"]*/b/treepnet-media/o/|media\.treepnet\.com/)[^"]*', 'g'))[1] u
        from posts where user_id = p_uid
      union all select content_url from stories where user_id = p_uid
      union all select cover_url from story_highlights where user_id = p_uid
      union all select avatar_url from profiles where id = p_uid
      union all select url from images where owner_id = p_uid
      union all select url from videos where owner_id = p_uid
      union all select first_frame_url from videos where owner_id = p_uid
    ) s
   where u like 'https://objectstorage.%/b/treepnet-media/o/%'
      or u like 'https://media.treepnet.com/%';

  -- Stories (children first, then the story)
  delete from story_likes           where user_id = p_uid;
  delete from story_views           where user_id = p_uid;
  delete from story_highlight_items where highlight_id in
      (select id from story_highlights where user_id = p_uid);
  delete from story_highlights      where user_id = p_uid;
  delete from location_stories      where user_id = p_uid;
  delete from stories               where user_id = p_uid;

  -- Posts and their dependencies
  delete from likes                 where user_id = p_uid;
  delete from comments              where user_id = p_uid;
  delete from saved_posts           where user_id = p_uid;
  delete from archived_posts        where user_id = p_uid;
  delete from images                where owner_id = p_uid;
  delete from videos                where owner_id = p_uid;
  delete from posts                 where user_id = p_uid;

  -- Legacy chat: every conversation the account was in, both sides (messages,
  -- attachments, reactions, participants and reads go with it).
  delete from conversations         where id in
      (select conversation_id from participants where user_id = p_uid);
  delete from attachments           where message_id in
      (select id from messages where from_id = p_uid);
  delete from messages              where from_id = p_uid;
  delete from participants          where user_id = p_uid;

  -- Social graph and the rest
  delete from subscriptions         where subscriber_id = p_uid
                                        or subscribed_to_id = p_uid;
  delete from blocked_users         where blocker_id = p_uid
                                        or blocked_id = p_uid;
  delete from referrals             where referrer_id = p_uid
                                        or invited_id = p_uid;
  delete from saved_profiles        where saver_id = p_uid;
  delete from visited_regions       where user_id = p_uid;

  -- Not linked by a foreign key, so nothing cascades here.
  delete from push_outbox           where recipient_id = p_uid
                                        or actor_id = p_uid;
  delete from analytics.activity    where user_id = p_uid;

  -- The profile row itself (its password row cascades)
  delete from profiles              where id = p_uid;

  if v_email is not null then
    delete from auth_codes             where lower(email) = v_email;
    delete from account_deletion_codes where lower(email) = v_email;
  end if;

  -- Firebase, the chat server and the media files are finished by the worker.
  insert into account_deletion_jobs (user_id, media) values (p_uid, v_media);
end;
$$;


--
-- Name: delete_avatar(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_avatar(avatar_url text, OUT status integer, OUT content text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
 begin
   select
       into status, content
            result.status, result.content
       from public.delete_storage_object('avatars', avatar_url) as result;
 end;
 $$;


--
-- Name: delete_old_avatar(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_old_avatar() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
  -- Supabase Storage endi yo'q; eski blobni o'chirish backendga ko'chirilishi
  -- kerak. Trigger hech narsa qilmaydi, faqat yozuvga to'sqinlik qilmaydi.
  -- BEFORE triggerda NULL qaytarish amalni BEKOR QILADI, shuning uchun
  -- INSERT/UPDATE uchun NEW, DELETE uchun OLD qaytariladi.
  return coalesce(new, old);
end;
$$;


--
-- Name: delete_old_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_old_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
 begin
   delete from public.profiles where id = old.id;
   return old;
 end;
 $$;


--
-- Name: delete_storage_object(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_storage_object(bucket text, object text, OUT status integer, OUT content text) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
 declare
   project_url text := '<PROJECT_URL>';
   service_role_key text := '<SERVICE_ROLE_KEY>'; -- full access needed
   delete_object text := reverse(split_part(reverse(object), '/', 1));
   url text := project_url||'/storage/v1/object/'||bucket||'/'||delete_object;
 begin
   select
       into status, content
            result.status::int, result.content::text
       FROM extensions.http((
     'DELETE',
     url,
     ARRAY[extensions.http_header('authorization','Bearer '||service_role_key)],
     NULL,
     NULL)::extensions.http_request) as result;
 end;
 $$;


--
-- Name: enqueue_push(uuid, uuid, text, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enqueue_push(p_recipient uuid, p_actor uuid, p_type text, p_title text, p_body text, p_data jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_recipient is null or p_recipient = p_actor then
    return;
  end if;
  if p_actor is not null and exists (
    select 1 from blocked_users b
     where (b.blocker_id = p_recipient and b.blocked_id = p_actor)
        or (b.blocker_id = p_actor and b.blocked_id = p_recipient)
  ) then
    return;
  end if;
  if p_type in ('like', 'follow', 'follow_request') and exists (
    select 1 from push_outbox o
     where o.recipient_id = p_recipient
       and o.actor_id = p_actor
       and o.type = p_type
       and o.created_at > now() - interval '6 hours'
       and (o.data ->> 'post_id') is not distinct from (p_data ->> 'post_id')
  ) then
    return;
  end if;
  insert into push_outbox (recipient_id, actor_id, type, title, body, data)
  values (p_recipient, p_actor, p_type, p_title, p_body, coalesce(p_data, '{}'::jsonb));
end;
$$;


--
-- Name: feed_position(uuid, text, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.feed_position(p_post uuid, p_order text, p_exclude uuid[] DEFAULT '{}'::uuid[]) RETURNS integer
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select (ids.n - 1)::integer
    from feed_post_ids(p_order, p_exclude) with ordinality as ids(id, n)
   where ids.id = p_post
$$;


--
-- Name: feed_post_ids(text, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.feed_post_ids(p_order text, p_exclude uuid[]) RETURNS TABLE(id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: feed_post_rows(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.feed_post_rows(p_ids uuid[]) RETURNS SETOF public.feed_post
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: feed_posts(text, integer, integer, uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.feed_posts(p_order text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0, p_exclude uuid[] DEFAULT '{}'::uuid[]) RETURNS SETOF public.feed_post
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select * from feed_post_rows(array(
    select ids.id from feed_post_ids(p_order, p_exclude)
           with ordinality as ids(id, n)
     order by ids.n
     limit least(greatest(coalesce(p_limit, 20), 1), 100)
    offset greatest(coalesce(p_offset, 0), 0)
  ))
$$;


--
-- Name: follow_list(uuid, boolean, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.follow_list(p_user uuid, p_followers boolean, p_limit integer DEFAULT 30, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, bio text, is_private boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: handle_delete_post_media(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_delete_post_media() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  -- The same URLs delete_account_by_id collects: the post's media is a JSON
  -- string, matched as text.
  perform queue_media_deletion(array(
    select (regexp_matches(
      coalesce(old.media, ''),
      'https://(?:objectstorage\.[^"]*/b/treepnet-media/o/|media\.treepnet\.com/)[^"]*',
      'g'))[1]
  ));
  return old;
end;
$$;


--
-- Name: handle_delete_story_media(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_delete_story_media() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  -- Its highlight items are already gone (they cascade first), so this picks
  -- among the stories left in each highlight.
  update story_highlights h
     set cover_url = (
       select s.content_url
         from story_highlight_items i
         join stories s on s.id = i.story_id
        where i.highlight_id = h.id
        order by i.created_at, s.created_at
        limit 1)
   where h.cover_url = old.content_url;
  perform queue_media_deletion(array[old.content_url]);
  return old;
end;
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  insert into public.profiles (id, full_name, email, username, avatar_url, push_token)
  values (
    new.id, 
    coalesce(new.raw_user_meta_data->>'name', ''), 
    new.email,
    new.raw_user_meta_data->>'username',
    null,
    null
  );
  return new;
end;
$$;


--
-- Name: handle_update_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_update_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  update public.profiles
  set full_name = coalesce(new.raw_user_meta_data->>'name', ''),
      email = new.email
  where id = new.id;
  return new;
end;
$$;


--
-- Name: media_in_use(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.media_in_use(p_url text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select media_object_key(p_url) is not null and (
       exists (select 1 from posts where strpos(media, media_object_key(p_url)) > 0)
    or exists (select 1 from stories where strpos(content_url, media_object_key(p_url)) > 0)
    or exists (select 1 from story_highlights where strpos(cover_url, media_object_key(p_url)) > 0)
    or exists (select 1 from profiles where strpos(avatar_url, media_object_key(p_url)) > 0)
  )
$$;


--
-- Name: media_object_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.media_object_key(p_url text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  select nullif(coalesce(
    substring(p_url from '/b/treepnet-media/o/([^?#]+)'),
    substring(p_url from '^https://media\.treepnet\.com/([^?#]+)')
  ), '')
$$;


--
-- Name: notifications_keep(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notifications_keep() RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$ select 300 $$;


--
-- Name: notifications_prune(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notifications_prune(p_recipient uuid) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  delete from notifications
   where id in (select id from notifications
                 where recipient_id = p_recipient
                 order by created_at desc
                offset notifications_keep());
$$;


--
-- Name: notify_push_outbox(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_push_outbox() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify('push_outbox', '');
  return null;
end;
$$;


--
-- Name: post_by_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_by_id(p_id uuid) RETURNS SETOF public.feed_post
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select r.* from feed_post_rows(array[p_id]) r
   where can_view_author(r.user_id)
     and coalesce(r.media, '') not like '%file://%'
$$;


--
-- Name: post_likers(uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_likers(p_post uuid, p_limit integer DEFAULT 30, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, username text, full_name text, avatar_url text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: post_likers_in_followings(uuid[], integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_likers_in_followings(p_posts uuid[], p_per_post integer DEFAULT 3) RETURNS TABLE(post_id uuid, id uuid, username text, full_name text, avatar_url text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: post_thumb(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.post_thumb(p_media text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'public'
    AS $$
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


--
-- Name: posts_refresh_referral_tier(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.posts_refresh_referral_tier() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_referral_tier(old.user_id);
    return old;
  end if;
  perform public.refresh_referral_tier(new.user_id);
  return new;
end;
$$;


--
-- Name: profile_cards(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profile_cards(p_ids uuid[]) RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, referral_tier integer, referral_tier_expires_at timestamp with time zone, is_private boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select a.id, a.username, a.full_name, a.avatar_url, a.referral_tier,
         a.referral_tier_expires_at, a.is_private
    from profiles a
   where a.id = any (p_ids[1:200])
$$;


--
-- Name: profiles_quiet_updates(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_quiet_updates() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: push_actor_name(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.push_actor_name(p_actor uuid) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(NULLIF(username, ''), NULLIF(full_name, ''), 'Someone')
  FROM public.profiles WHERE id = p_actor;
$$;


--
-- Name: queue_media_deletion(text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.queue_media_deletion(p_urls text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_url text;
begin
  foreach v_url in array coalesce(p_urls, '{}') loop
    continue when media_object_key(v_url) is null or media_in_use(v_url);
    insert into media_deletion_queue (url) values (v_url)
      on conflict (url) do nothing;
  end loop;
end;
$$;


--
-- Name: redeem_referral(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_referral(p_handle text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_referrer uuid;
  v_me uuid := auth.uid();
  v_handle text := trim(coalesce(p_handle, ''));
begin
  if v_me is null then
    return 'unauthenticated';
  end if;
  if length(v_handle) = 0 then
    return 'unknown';
  end if;
  -- Only a sign-up counts: the app redeems right after creating the account.
  if not exists (
    select 1 from auth_credentials
     where user_id = v_me and created_at > now() - interval '1 hour'
  ) then
    return 'too_late';
  end if;

  select id into v_referrer
    from public.profiles
   where username = v_handle
   limit 1;

  -- The link may carry the id instead of the username.
  if v_referrer is null then
    begin
      v_referrer := v_handle::uuid;
      if not exists (select 1 from public.profiles where id = v_referrer) then
        v_referrer := null;
      end if;
    exception when others then
      v_referrer := null;
    end;
  end if;

  if v_referrer is null then
    return 'unknown';
  end if;
  if v_referrer = v_me then
    return 'self';
  end if;

  insert into public.referrals (referrer_id, invited_id)
       values (v_referrer, v_me)
  on conflict (invited_id) do nothing;

  -- A conflict inserts nothing: this account was invited already.
  if not found then
    return 'already';
  end if;

  perform public.refresh_referral_tier(v_referrer);
  return 'ok';
end;
$$;


--
-- Name: referrals_refresh_referrer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.referrals_refresh_referrer() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  perform refresh_referral_tier(old.referrer_id);
  return null;
end;
$$;


--
-- Name: refresh_referral_tier(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_referral_tier(p_user uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_tier      int := 0;
  v_locations int;
  v_regions   int;
  v_ratio     numeric;
  v_end       timestamptz := null;
  r           record;
begin
  -- Colour: how widely they explore.
  select count(*) filter (where location_lat is not null),
         count(distinct location_region)
           filter (where location_region is not null and location_region <> '')
    into v_locations, v_regions
    from public.posts
   where user_id = p_user;

  if v_locations > 0 and v_regions > 0 then
    v_ratio := case
                 when v_regions >= 2 then v_locations::numeric / v_regions
                 else v_locations::numeric / 2
               end;
    v_tier := case
                when v_ratio < 10 then 1
                when v_ratio < 20 then 2
                when v_ratio < 30 then 3
                when v_ratio < 40 then 4
                else 5
              end;
  end if;

  -- Duration: every 5th invite tops the subscription up by a month, extending
  -- the balance rather than restarting it.
  for r in
    select created_at,
           row_number() over (order by created_at) as rn
      from public.referrals
     where referrer_id = p_user
     order by created_at
  loop
    if r.rn % 5 = 0 then
      v_end := greatest(coalesce(v_end, r.created_at), r.created_at)
                 + interval '1 month';
    end if;
  end loop;

  -- Nothing on the map means nothing to show, however much premium is banked.
  if v_locations = 0 then
    v_tier := 0;
  end if;

  update public.profiles
     set referral_tier            = v_tier,
         referral_tier_expires_at = v_end
   where id = p_user;
end;
$$;


--
-- Name: refresh_story_visibility(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_story_visibility(p_story uuid DEFAULT NULL::uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  changed integer;
begin
  update stories s
     set visibility = story_visibility(s.id, s.expires_at)
   where (p_story is null or s.id = p_story)
     and s.visibility is distinct from story_visibility(s.id, s.expires_at);
  get diagnostics changed = row_count;
  return changed;
end;
$$;


--
-- Name: saved_posts_page(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.saved_posts_page(p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS SETOF public.feed_post
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: search_key(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_key(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    SET search_path TO 'public'
    AS $$
  select replace(replace(replace(
           translate(
             replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
               lower(btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g'))),
               'щ', 'sh'), 'ш', 'sh'), 'ч', 'ch'), 'ц', 'ts'), 'ю', 'yu'),
               'я', 'ya'), 'ё', 'yo'), 'ж', 'j'), 'х', 'h'), 'ҳ', 'h'),
             -- one letter for one; the rest (ъ ь and apostrophes) are dropped
             'абвгдезийклмнопрстуфыэўқғъь''’ʻʼ`',
             'abvgdeziyklmnoprstufieoqg'),
           'kh', 'h'), 'zh', 'j'), 'x', 'h')
$$;


--
-- Name: search_profiles(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.search_profiles(p_query text, p_limit integer DEFAULT 8, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, avatar_url text, full_name text, username text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with q as (
    select replace(replace(replace(public.search_key(p_query),
             '\', '\\'), '%', '\%'), '_', '\_') as k
  )
  select p.id, p.avatar_url, p.full_name, p.username
    from profiles p, q
   where q.k <> ''
     and p.id is distinct from auth.uid()
     and (public.search_key(p.username) like '%' || q.k || '%' escape '\'
          or public.search_key(p.full_name) like '%' || q.k || '%' escape '\')
   order by (public.search_key(p.username) like q.k || '%' escape '\'
             or public.search_key(p.full_name) like q.k || '%' escape '\') desc,
            p.username
   limit least(greatest(coalesce(p_limit, 8), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0)
$$;


--
-- Name: server_created_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.server_created_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  else
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;


--
-- Name: stories_server_times(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stories_server_times() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.expires_at := now() + interval '24 hours';
  else
    new.created_at := old.created_at;
    new.expires_at := old.expires_at;
  end if;
  return new;
end;
$$;


--
-- Name: stories_set_visibility(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.stories_set_visibility() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  new.visibility := story_visibility(new.id, new.expires_at);
  return new;
end;
$$;


--
-- Name: story_by_id(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.story_by_id(p_id uuid) RETURNS TABLE(id uuid, user_id uuid, content_type text, content_url text, duration integer, created_at timestamp with time zone, expires_at timestamp with time zone, location_name text, location_lat double precision, location_lng double precision, username text, full_name text, avatar_url text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select s.id, s.user_id, s.content_type::text, s.content_url, s.duration,
         s.created_at, s.expires_at, s.location_name, s.location_lat,
         s.location_lng, a.username, a.full_name, a.avatar_url
    from stories s
    join profiles a on a.id = s.user_id
   where s.id = p_id
     and (s.visibility = 'public' or s.user_id = auth.uid())
     and can_view_author(s.user_id)
$$;


--
-- Name: story_highlight_items_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.story_highlight_items_owner() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  select h.user_id into new.user_id from story_highlights h
   where h.id = new.highlight_id;
  return new;
end;
$$;


--
-- Name: story_links_changed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.story_links_changed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if tg_op in ('UPDATE', 'DELETE') then
    perform refresh_story_visibility(old.story_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    perform refresh_story_visibility(new.story_id);
  end if;
  return null;
end;
$$;


--
-- Name: story_views_set_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.story_views_set_owner() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  select s.user_id into new.story_owner_id
    from public.stories s
   where s.id = new.story_id;
  return new;
end;
$$;


--
-- Name: story_visibility(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.story_visibility(p_id uuid, p_expires_at timestamp with time zone) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select case
    when p_expires_at > now()
      or exists (select 1 from story_highlight_items i where i.story_id = p_id)
      or exists (select 1 from location_stories l where l.story_id = p_id)
    then 'public'
    else 'owner'
  end
$$;


--
-- Name: subscriptions_enforce(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.subscriptions_enforce() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if tg_op = 'INSERT' then
    if exists (
      select 1 from public.blocked_users b
       where (b.blocker_id = new.subscriber_id and b.blocked_id = new.subscribed_to_id)
          or (b.blocker_id = new.subscribed_to_id and b.blocked_id = new.subscriber_id)
    ) then
      raise exception 'cannot follow: blocked' using errcode = '42501';
    end if;
    new.status := case
      when coalesce((select p.is_private from public.profiles p
                      where p.id = new.subscribed_to_id), false)
        then 'pending'
      else 'accepted'
    end;
  else
    if new.subscriber_id is distinct from old.subscriber_id
       or new.subscribed_to_id is distinct from old.subscribed_to_id then
      raise exception 'cannot change who follows whom' using errcode = '42501';
    end if;
    if new.status is null or new.status not in ('pending', 'accepted') then
      raise exception 'invalid follow status' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


--
-- Name: suggested_profiles(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.suggested_profiles(p_limit integer DEFAULT 50) RETURNS TABLE(id uuid, username text, full_name text, avatar_url text, bio text, is_private boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_scoping_on_comment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_scoping_on_comment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_scoping_on_like(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_scoping_on_like() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_scoping_on_post(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_scoping_on_post() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_scoping_on_profile(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_scoping_on_profile() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: sync_scoping_on_subscription(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_scoping_on_subscription() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
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


--
-- Name: track_presence(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.track_presence() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'analytics'
    AS $$
begin
  new.last_seen_at := now();
  insert into analytics.activity (user_id, minute)
  values (new.id, date_trunc('minute', now()))
  on conflict do nothing;
  return new;
end;
$$;


--
-- Name: trg_push_on_comment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_push_on_comment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_owner uuid;
  v_actor text;
BEGIN
  IF NEW.post_id IS NULL THEN RETURN NEW; END IF;
  SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
  IF v_owner IS NULL THEN RETURN NEW; END IF;
  v_actor := public.push_actor_name(NEW.user_id);
  PERFORM public.enqueue_push(
    v_owner, NEW.user_id, 'comment',
    v_actor, 'commented: ' || left(COALESCE(NEW.content, ''), 120),
    jsonb_build_object('type','comment','actor_id',NEW.user_id,'post_id',NEW.post_id)
  );
  RETURN NEW;
END;
$$;


--
-- Name: trg_push_on_like(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_push_on_like() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_owner uuid;
  v_actor text;
BEGIN
  IF NEW.post_id IS NULL THEN RETURN NEW; END IF;
  SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
  IF v_owner IS NULL THEN RETURN NEW; END IF;
  v_actor := public.push_actor_name(NEW.user_id);
  PERFORM public.enqueue_push(
    v_owner, NEW.user_id, 'like',
    v_actor, 'liked your post',
    jsonb_build_object('type','like','actor_id',NEW.user_id,'post_id',NEW.post_id)
  );
  RETURN NEW;
END;
$$;


--
-- Name: trg_push_on_subscription(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_push_on_subscription() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_actor text;
  v_type  text;
  v_body  text;
BEGIN
  v_actor := public.push_actor_name(NEW.subscriber_id);
  IF NEW.status = 'pending' THEN
    v_type := 'follow_request';
    v_body := 'requested to follow you';
  ELSE
    v_type := 'follow';
    v_body := 'started following you';
  END IF;
  PERFORM public.enqueue_push(
    NEW.subscribed_to_id, NEW.subscriber_id, v_type,
    v_actor, v_body,
    jsonb_build_object('type',v_type,'actor_id',NEW.subscriber_id)
  );
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: profile_presence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profile_presence (
    user_id uuid NOT NULL,
    last_seen_at timestamp with time zone NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text NOT NULL,
    email text NOT NULL,
    username text,
    avatar_url text,
    push_token text,
    referral_tier integer DEFAULT 0 NOT NULL,
    bio text,
    birthday date,
    telegram text,
    website text,
    instagram text,
    gender text,
    is_private boolean DEFAULT false,
    onboarded_at timestamp with time zone,
    referral_tier_expires_at timestamp with time zone,
    notifications_seen_at timestamp with time zone,
    last_seen_at timestamp with time zone,
    lang text,
    CONSTRAINT profiles_lang_check CHECK ((lang = ANY (ARRAY['en'::text, 'ru'::text]))),
    CONSTRAINT username_format CHECK ((username ~ '^[a-z0-9_.]+$'::text)),
    CONSTRAINT username_length CHECK (((char_length(username) >= 3) AND (char_length(username) <= 16)))
);


--
-- Name: active_users; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.active_users AS
 SELECT count(*) FILTER (WHERE (seen >= (now() - '1 day'::interval))) AS dau,
    count(*) FILTER (WHERE (seen >= (now() - '7 days'::interval))) AS wau,
    count(*) FILTER (WHERE (seen >= (now() - '30 days'::interval))) AS mau
   FROM ( SELECT COALESCE(pp.last_seen_at, p.last_seen_at) AS seen
           FROM (public.profiles p
             LEFT JOIN public.profile_presence pp ON ((pp.user_id = p.id)))) s;


--
-- Name: activity; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics.activity (
    user_id uuid NOT NULL,
    minute timestamp with time zone NOT NULL
);


--
-- Name: blocked_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blocked_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: blocked; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.blocked AS
 SELECT blocker_id,
    blocked_id,
    created_at
   FROM public.blocked_users;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id uuid NOT NULL,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    replied_to_comment_id uuid,
    post_owner_id uuid,
    author_username text,
    author_full_name text,
    author_avatar_url text,
    likes_count integer DEFAULT 0 NOT NULL,
    liked_by_author boolean DEFAULT false NOT NULL
);


--
-- Name: comments; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.comments AS
 SELECT id,
    post_id,
    user_id,
    created_at,
    (replied_to_comment_id IS NOT NULL) AS is_reply
   FROM public.comments;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type public.conversation_type NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: conversations; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.conversations AS
 SELECT id,
    created_at
   FROM public.conversations;


--
-- Name: daily_active; Type: TABLE; Schema: analytics; Owner: -
--

CREATE TABLE analytics.daily_active (
    day date NOT NULL,
    dau integer NOT NULL,
    wau integer NOT NULL,
    mau integer NOT NULL,
    signups integer DEFAULT 0 NOT NULL
);


--
-- Name: subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.subscriptions (
    id uuid NOT NULL,
    subscriber_id uuid NOT NULL,
    subscribed_to_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    status text DEFAULT 'accepted'::text NOT NULL,
    CONSTRAINT subscriptions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text])))
);


--
-- Name: follows; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.follows AS
 SELECT id,
    subscriber_id,
    subscribed_to_id,
    created_at,
    COALESCE(status, 'accepted'::text) AS status
   FROM public.subscriptions;


--
-- Name: story_highlights; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.story_highlights (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    name text NOT NULL,
    cover_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: highlights; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.highlights AS
 SELECT id,
    user_id,
    created_at
   FROM public.story_highlights;


--
-- Name: likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid,
    user_id uuid NOT NULL,
    comment_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT like_has_either_comment_or_post CHECK ((((comment_id IS NOT NULL) AND (post_id IS NULL)) OR ((comment_id IS NULL) AND (post_id IS NOT NULL))))
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    from_id uuid NOT NULL,
    type public.message_type NOT NULL,
    message text NOT NULL,
    reply_message_id uuid,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    updated_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    is_read integer DEFAULT 0 NOT NULL,
    is_deleted integer DEFAULT 0 NOT NULL,
    is_edited integer DEFAULT 0 NOT NULL,
    reply_message_username text,
    reply_message_attachment_url text,
    shared_post_id uuid,
    from_username text,
    reply_message_message text,
    shared_story_id uuid
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    caption text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    media text,
    location text,
    location_country text,
    location_region text,
    location_name text,
    location_lat double precision,
    location_lng double precision
);


--
-- Name: referrals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referrals (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    referrer_id uuid NOT NULL,
    invited_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT referrals_no_self CHECK ((referrer_id <> invited_id))
);


--
-- Name: stories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    content_type public.story_content_type NOT NULL,
    content_url text NOT NULL,
    duration integer,
    created_at timestamp with time zone DEFAULT (now() AT TIME ZONE 'utc'::text) NOT NULL,
    expires_at timestamp with time zone DEFAULT ((now() AT TIME ZONE 'utc'::text) + '1 day'::interval) NOT NULL,
    location_name text,
    location_lat double precision,
    location_lng double precision,
    visibility text DEFAULT 'public'::text NOT NULL,
    CONSTRAINT stories_visibility_check CHECK ((visibility = ANY (ARRAY['public'::text, 'owner'::text])))
);


--
-- Name: kpis; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.kpis AS
 SELECT ( SELECT count(*) AS count
           FROM public.profiles) AS total_users,
    ( SELECT count(*) AS count
           FROM public.posts) AS total_posts,
    ( SELECT count(*) AS count
           FROM public.stories) AS total_stories,
    ( SELECT count(*) AS count
           FROM public.comments) AS total_comments,
    ( SELECT count(*) AS count
           FROM public.likes) AS total_likes,
    ( SELECT count(*) AS count
           FROM public.subscriptions) AS total_follows,
    ( SELECT count(*) AS count
           FROM public.referrals) AS total_referrals,
    ( SELECT count(*) AS count
           FROM public.messages) AS total_messages;


--
-- Name: likes; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.likes AS
 SELECT id,
    post_id,
    comment_id,
    user_id,
    created_at
   FROM public.likes;


--
-- Name: messages; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.messages AS
 SELECT id,
    conversation_id,
    from_id,
    (type)::text AS type,
    created_at
   FROM public.messages;


--
-- Name: posts; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.posts AS
 SELECT id,
    user_id,
    created_at,
    (location IS NOT NULL) AS has_location,
    location_country,
    location_region,
    location_name
   FROM public.posts;


--
-- Name: push_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    actor_id uuid,
    type text NOT NULL,
    title text,
    body text,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    claimed_at timestamp with time zone,
    sent_at timestamp with time zone
);


--
-- Name: push; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.push AS
 SELECT recipient_id,
    type,
    status,
    created_at,
    sent_at
   FROM public.push_outbox;


--
-- Name: referral_counts; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.referral_counts AS
 SELECT r.referrer_id AS user_id,
    p.username,
    count(*) AS invited_count
   FROM (public.referrals r
     JOIN public.profiles p ON ((p.id = r.referrer_id)))
  GROUP BY r.referrer_id, p.username;


--
-- Name: referrals; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.referrals AS
 SELECT referrer_id,
    invited_id,
    created_at
   FROM public.referrals;


--
-- Name: saved_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    post_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: saves; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.saves AS
 SELECT user_id,
    post_id,
    created_at
   FROM public.saved_posts;


--
-- Name: auth_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_credentials (
    user_id uuid NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: signups; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.signups AS
 SELECT user_id,
    created_at
   FROM public.auth_credentials;


--
-- Name: stories; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.stories AS
 SELECT id,
    user_id,
    created_at,
    expires_at,
    (content_type)::text AS content_type,
    (expires_at > now()) AS is_active
   FROM public.stories;


--
-- Name: story_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.story_views (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    story_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    story_owner_id uuid NOT NULL
);


--
-- Name: story_view_events; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.story_view_events AS
 SELECT story_id,
    created_at
   FROM public.story_views;


--
-- Name: story_views; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.story_views AS
 SELECT story_id,
    count(*) AS views_count
   FROM public.story_views
  GROUP BY story_id;


--
-- Name: visited_regions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visited_regions (
    user_id uuid NOT NULL,
    region_iso text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: users; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.users AS
 SELECT p.id,
    p.username,
    ((p.avatar_url IS NOT NULL) AND (p.avatar_url <> ''::text)) AS has_avatar,
    ((p.bio IS NOT NULL) AND (p.bio <> ''::text)) AS has_bio,
    p.is_private,
    p.referral_tier,
    (EXTRACT(year FROM p.birthday))::integer AS birth_year,
    ((p.push_token IS NOT NULL) AND (p.push_token <> ''::text)) AS has_push_token,
    COALESCE(pp.last_seen_at, p.last_seen_at) AS last_seen_at,
    COALESCE(c.created_at, ( SELECT min(x.ts) AS min
           FROM ( SELECT min(posts.created_at) AS ts
                   FROM public.posts
                  WHERE (posts.user_id = p.id)
                UNION ALL
                 SELECT min(stories.created_at) AS min
                   FROM public.stories
                  WHERE (stories.user_id = p.id)
                UNION ALL
                 SELECT min(likes.created_at) AS min
                   FROM public.likes
                  WHERE (likes.user_id = p.id)
                UNION ALL
                 SELECT min(comments.created_at) AS min
                   FROM public.comments
                  WHERE (comments.user_id = p.id)
                UNION ALL
                 SELECT min(subscriptions.created_at) AS min
                   FROM public.subscriptions
                  WHERE (subscriptions.subscriber_id = p.id)
                UNION ALL
                 SELECT min(visited_regions.created_at) AS min
                   FROM public.visited_regions
                  WHERE (visited_regions.user_id = p.id)) x)) AS signup_at,
    (c.created_at IS NULL) AS signup_estimated,
    p.onboarded_at
   FROM ((public.profiles p
     LEFT JOIN public.auth_credentials c ON ((c.user_id = p.id)))
     LEFT JOIN public.profile_presence pp ON ((pp.user_id = p.id)));


--
-- Name: visited_regions; Type: VIEW; Schema: analytics; Owner: -
--

CREATE VIEW analytics.visited_regions AS
 SELECT user_id,
    region_iso,
    created_at
   FROM public.visited_regions;


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    id uuid NOT NULL,
    email text
);


--
-- Name: account_deletion_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_deletion_codes (
    email text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: account_deletion_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_deletion_jobs (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    media text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    next_attempt_at timestamp with time zone DEFAULT now() NOT NULL,
    last_error text,
    done_steps text[] DEFAULT '{}'::text[] NOT NULL
);


--
-- Name: account_deletion_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_deletion_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_deletion_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_deletion_jobs_id_seq OWNED BY public.account_deletion_jobs.id;


--
-- Name: archived_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.archived_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    post_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    message_id uuid NOT NULL,
    title text,
    text text,
    title_link text,
    image_url text,
    thumb_url text,
    author_name text,
    author_link text,
    asset_url text,
    og_scrape_url text,
    type public.attachment_type NOT NULL
);


--
-- Name: auth_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_codes (
    email text NOT NULL,
    code text NOT NULL,
    purpose text NOT NULL,
    payload jsonb,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: conversation_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_reads (
    id text NOT NULL,
    conversation_id uuid NOT NULL,
    user_id uuid NOT NULL,
    last_read_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.images (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    url text NOT NULL,
    blur_hash text
);


--
-- Name: location_stories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.location_stories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    story_id uuid NOT NULL,
    region_iso text NOT NULL,
    lat double precision,
    lng double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: media_deletion_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_deletion_queue (
    url text NOT NULL,
    queued_at timestamp with time zone DEFAULT now() NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    last_error text,
    next_attempt_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: message_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_reactions (
    id uuid NOT NULL,
    message_id uuid NOT NULL,
    conversation_id uuid NOT NULL,
    user_id uuid NOT NULL,
    emoji text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    type text NOT NULL,
    source_id uuid NOT NULL,
    post_id uuid,
    content text,
    post_thumb text,
    actor_username text,
    actor_full_name text,
    actor_avatar_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_type_check CHECK ((type = ANY (ARRAY['like'::text, 'comment'::text, 'follow'::text, 'follow_request'::text])))
);


--
-- Name: participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    conversation_id uuid NOT NULL
);


--
-- Name: post_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_stats (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    likes_count integer DEFAULT 0 NOT NULL,
    comments_count integer DEFAULT 0 NOT NULL
);


--
-- Name: profile_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profile_stats (
    id uuid NOT NULL,
    posts_count integer DEFAULT 0 NOT NULL,
    places_count integer DEFAULT 0 NOT NULL,
    followers_count integer DEFAULT 0 NOT NULL,
    following_count integer DEFAULT 0 NOT NULL
);


--
-- Name: saved_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    saver_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: story_highlight_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.story_highlight_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    highlight_id uuid NOT NULL,
    story_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid
);


--
-- Name: story_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.story_likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    story_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: typing_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.typing_status (
    id text NOT NULL,
    conversation_id uuid NOT NULL,
    user_id uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: videos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.videos (
    id uuid NOT NULL,
    owner_id uuid NOT NULL,
    url text NOT NULL,
    first_frame_url text NOT NULL,
    blur_hash text NOT NULL
);


--
-- Name: account_deletion_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_jobs ALTER COLUMN id SET DEFAULT nextval('public.account_deletion_jobs_id_seq'::regclass);


--
-- Name: activity activity_pkey; Type: CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics.activity
    ADD CONSTRAINT activity_pkey PRIMARY KEY (user_id, minute);


--
-- Name: daily_active daily_active_pkey; Type: CONSTRAINT; Schema: analytics; Owner: -
--

ALTER TABLE ONLY analytics.daily_active
    ADD CONSTRAINT daily_active_pkey PRIMARY KEY (day);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: account_deletion_codes account_deletion_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_codes
    ADD CONSTRAINT account_deletion_codes_pkey PRIMARY KEY (email);


--
-- Name: account_deletion_jobs account_deletion_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_deletion_jobs
    ADD CONSTRAINT account_deletion_jobs_pkey PRIMARY KEY (id);


--
-- Name: archived_posts archived_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archived_posts
    ADD CONSTRAINT archived_posts_pkey PRIMARY KEY (id);


--
-- Name: archived_posts archived_posts_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archived_posts
    ADD CONSTRAINT archived_posts_unique UNIQUE (user_id, post_id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: auth_codes auth_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_codes
    ADD CONSTRAINT auth_codes_pkey PRIMARY KEY (email);


--
-- Name: auth_credentials auth_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_credentials
    ADD CONSTRAINT auth_credentials_pkey PRIMARY KEY (user_id);


--
-- Name: blocked_users blocked_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_pkey PRIMARY KEY (id);


--
-- Name: blocked_users blocked_users_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_unique UNIQUE (blocker_id, blocked_id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: conversation_reads conversation_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT conversation_reads_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: images images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_pkey PRIMARY KEY (id);


--
-- Name: likes likes_comment_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_comment_id_key UNIQUE (user_id, comment_id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (id);


--
-- Name: likes likes_post_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_post_id_key UNIQUE (user_id, post_id);


--
-- Name: location_stories location_stories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_stories
    ADD CONSTRAINT location_stories_pkey PRIMARY KEY (id);


--
-- Name: location_stories location_stories_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_stories
    ADD CONSTRAINT location_stories_unique UNIQUE (user_id, story_id, region_iso, lat, lng);


--
-- Name: media_deletion_queue media_deletion_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_deletion_queue
    ADD CONSTRAINT media_deletion_queue_pkey PRIMARY KEY (url);


--
-- Name: message_reactions message_reactions_one_per_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_one_per_user UNIQUE (message_id, user_id);


--
-- Name: message_reactions message_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_source_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_source_id_key UNIQUE (source_id);


--
-- Name: participants participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT participants_pkey PRIMARY KEY (id);


--
-- Name: post_stats post_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats
    ADD CONSTRAINT post_stats_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: profile_presence profile_presence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_presence
    ADD CONSTRAINT profile_presence_pkey PRIMARY KEY (user_id);


--
-- Name: profile_stats profile_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_stats
    ADD CONSTRAINT profile_stats_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_email_key UNIQUE (email);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: push_outbox push_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_outbox
    ADD CONSTRAINT push_outbox_pkey PRIMARY KEY (id);


--
-- Name: referrals referrals_invited_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_invited_unique UNIQUE (invited_id);


--
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);


--
-- Name: saved_posts saved_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_posts
    ADD CONSTRAINT saved_posts_pkey PRIMARY KEY (id);


--
-- Name: saved_posts saved_posts_user_post_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_posts
    ADD CONSTRAINT saved_posts_user_post_key UNIQUE (user_id, post_id);


--
-- Name: saved_profiles saved_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_profiles
    ADD CONSTRAINT saved_profiles_pkey PRIMARY KEY (id);


--
-- Name: saved_profiles saved_profiles_saver_id_profile_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_profiles
    ADD CONSTRAINT saved_profiles_saver_id_profile_id_key UNIQUE (saver_id, profile_id);


--
-- Name: stories stories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stories
    ADD CONSTRAINT stories_pkey PRIMARY KEY (id);


--
-- Name: story_highlight_items story_highlight_items_highlight_id_story_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlight_items
    ADD CONSTRAINT story_highlight_items_highlight_id_story_id_key UNIQUE (highlight_id, story_id);


--
-- Name: story_highlight_items story_highlight_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlight_items
    ADD CONSTRAINT story_highlight_items_pkey PRIMARY KEY (id);


--
-- Name: story_highlights story_highlights_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlights
    ADD CONSTRAINT story_highlights_pkey PRIMARY KEY (id);


--
-- Name: story_likes story_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_pkey PRIMARY KEY (id);


--
-- Name: story_likes story_likes_story_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_story_id_user_id_key UNIQUE (story_id, user_id);


--
-- Name: story_views story_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_views
    ADD CONSTRAINT story_views_pkey PRIMARY KEY (id);


--
-- Name: story_views story_views_story_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_views
    ADD CONSTRAINT story_views_story_id_user_id_key UNIQUE (story_id, user_id);


--
-- Name: subscriptions subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_pkey PRIMARY KEY (id);


--
-- Name: typing_status typing_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.typing_status
    ADD CONSTRAINT typing_status_pkey PRIMARY KEY (id);


--
-- Name: participants unique_participant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT unique_participant UNIQUE (user_id, conversation_id);


--
-- Name: videos videos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id);


--
-- Name: visited_regions visited_regions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visited_regions
    ADD CONSTRAINT visited_regions_pkey PRIMARY KEY (id);


--
-- Name: visited_regions visited_regions_user_region_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visited_regions
    ADD CONSTRAINT visited_regions_user_region_key UNIQUE (user_id, region_iso);


--
-- Name: activity_minute_idx; Type: INDEX; Schema: analytics; Owner: -
--

CREATE INDEX activity_minute_idx ON analytics.activity USING btree (minute);


--
-- Name: archived_posts_post_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX archived_posts_post_idx ON public.archived_posts USING btree (post_id);


--
-- Name: blocked_users_blocked_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX blocked_users_blocked_idx ON public.blocked_users USING btree (blocked_id);


--
-- Name: comments_post_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_post_idx ON public.comments USING btree (post_id);


--
-- Name: comments_post_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_post_owner_idx ON public.comments USING btree (post_id, post_owner_id);


--
-- Name: comments_replied_to_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_replied_to_idx ON public.comments USING btree (replied_to_comment_id) WHERE (replied_to_comment_id IS NOT NULL);


--
-- Name: comments_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_user_idx ON public.comments USING btree (user_id);


--
-- Name: conversation_reads_conversation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_reads_conversation_idx ON public.conversation_reads USING btree (conversation_id);


--
-- Name: likes_comment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX likes_comment_idx ON public.likes USING btree (comment_id) WHERE (comment_id IS NOT NULL);


--
-- Name: likes_post_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX likes_post_idx ON public.likes USING btree (post_id);


--
-- Name: location_stories_place_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX location_stories_place_idx ON public.location_stories USING btree (user_id, region_iso);


--
-- Name: location_stories_story_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX location_stories_story_idx ON public.location_stories USING btree (story_id);


--
-- Name: message_reactions_conversation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX message_reactions_conversation_idx ON public.message_reactions USING btree (conversation_id);


--
-- Name: message_reactions_message_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX message_reactions_message_idx ON public.message_reactions USING btree (message_id);


--
-- Name: notifications_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_actor_idx ON public.notifications USING btree (actor_id);


--
-- Name: notifications_recipient_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_recipient_idx ON public.notifications USING btree (recipient_id, created_at DESC);


--
-- Name: posts_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_user_idx ON public.posts USING btree (user_id);


--
-- Name: profiles_full_name_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_full_name_trgm_idx ON public.profiles USING gin (public.search_key(full_name) public.gin_trgm_ops);


--
-- Name: profiles_username_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);


--
-- Name: profiles_username_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX profiles_username_trgm_idx ON public.profiles USING gin (public.search_key(username) public.gin_trgm_ops);


--
-- Name: push_outbox_dedup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX push_outbox_dedup_idx ON public.push_outbox USING btree (recipient_id, actor_id, type, created_at);


--
-- Name: push_outbox_pending_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX push_outbox_pending_idx ON public.push_outbox USING btree (created_at) WHERE (status = 'pending'::text);


--
-- Name: referrals_referrer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referrals_referrer_idx ON public.referrals USING btree (referrer_id, created_at);


--
-- Name: saved_posts_post_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_posts_post_idx ON public.saved_posts USING btree (post_id);


--
-- Name: saved_profiles_profile_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_profiles_profile_idx ON public.saved_profiles USING btree (profile_id);


--
-- Name: saved_profiles_saver_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX saved_profiles_saver_idx ON public.saved_profiles USING btree (saver_id);


--
-- Name: stories_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stories_user_idx ON public.stories USING btree (user_id);


--
-- Name: story_highlight_items_highlight_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_highlight_items_highlight_idx ON public.story_highlight_items USING btree (highlight_id);


--
-- Name: story_highlight_items_story_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_highlight_items_story_idx ON public.story_highlight_items USING btree (story_id);


--
-- Name: story_highlight_items_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_highlight_items_user_idx ON public.story_highlight_items USING btree (user_id);


--
-- Name: story_highlights_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_highlights_user_idx ON public.story_highlights USING btree (user_id);


--
-- Name: story_likes_story_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_likes_story_idx ON public.story_likes USING btree (story_id);


--
-- Name: story_likes_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_likes_user_idx ON public.story_likes USING btree (user_id);


--
-- Name: story_views_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_views_owner_idx ON public.story_views USING btree (story_owner_id);


--
-- Name: story_views_story_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_views_story_idx ON public.story_views USING btree (story_id);


--
-- Name: story_views_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX story_views_user_idx ON public.story_views USING btree (user_id);


--
-- Name: subscriptions_pair_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX subscriptions_pair_unique ON public.subscriptions USING btree (subscriber_id, subscribed_to_id);


--
-- Name: subscriptions_to_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX subscriptions_to_idx ON public.subscriptions USING btree (subscribed_to_id);


--
-- Name: typing_status_conversation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX typing_status_conversation_idx ON public.typing_status USING btree (conversation_id);


--
-- Name: visited_regions_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX visited_regions_user_idx ON public.visited_regions USING btree (user_id);


--
-- Name: profiles before_profile_changes; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER before_profile_changes BEFORE DELETE OR UPDATE OF avatar_url ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.delete_old_avatar();


--
-- Name: posts clear_posts_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER clear_posts_trigger AFTER TRUNCATE ON public.posts FOR EACH STATEMENT EXECUTE FUNCTION public.clear_posts_objects();


--
-- Name: stories clear_stories_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER clear_stories_trigger AFTER TRUNCATE ON public.stories FOR EACH STATEMENT EXECUTE FUNCTION public.clear_stories_objects();


--
-- Name: comments comments_fill; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comments_fill BEFORE INSERT OR UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.comments_fill();


--
-- Name: location_stories location_stories_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER location_stories_visibility AFTER INSERT OR DELETE OR UPDATE ON public.location_stories FOR EACH ROW EXECUTE FUNCTION public.story_links_changed();


--
-- Name: posts on_post_deleted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_post_deleted AFTER DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.handle_delete_post_media();


--
-- Name: stories on_story_deleted; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER on_story_deleted AFTER DELETE ON public.stories FOR EACH ROW EXECUTE FUNCTION public.handle_delete_story_media();


--
-- Name: posts posts_refresh_referral_tier; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER posts_refresh_referral_tier AFTER INSERT OR DELETE OR UPDATE OF location_lat, location_region ON public.posts FOR EACH ROW EXECUTE FUNCTION public.posts_refresh_referral_tier();


--
-- Name: comments push_on_comment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER push_on_comment AFTER INSERT ON public.comments FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_comment();


--
-- Name: likes push_on_like; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER push_on_like AFTER INSERT ON public.likes FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_like();


--
-- Name: subscriptions push_on_subscription; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER push_on_subscription AFTER INSERT ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_subscription();


--
-- Name: push_outbox push_outbox_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER push_outbox_notify AFTER INSERT ON public.push_outbox FOR EACH STATEMENT EXECUTE FUNCTION public.notify_push_outbox();


--
-- Name: referrals referrals_refresh_referrer; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER referrals_refresh_referrer AFTER DELETE ON public.referrals FOR EACH ROW EXECUTE FUNCTION public.referrals_refresh_referrer();


--
-- Name: archived_posts server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.archived_posts FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: comments server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: likes server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: location_stories server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.location_stories FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: posts server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: saved_posts server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.saved_posts FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: saved_profiles server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.saved_profiles FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: story_highlight_items server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.story_highlight_items FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: story_highlights server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.story_highlights FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: story_likes server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.story_likes FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: story_views server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.story_views FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: visited_regions server_created_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER server_created_at BEFORE INSERT OR UPDATE ON public.visited_regions FOR EACH ROW EXECUTE FUNCTION public.server_created_at();


--
-- Name: stories stories_server_times; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stories_server_times BEFORE INSERT OR UPDATE ON public.stories FOR EACH ROW EXECUTE FUNCTION public.stories_server_times();


--
-- Name: stories stories_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER stories_visibility BEFORE INSERT OR UPDATE ON public.stories FOR EACH ROW EXECUTE FUNCTION public.stories_set_visibility();


--
-- Name: story_highlight_items story_highlight_items_owner; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER story_highlight_items_owner BEFORE INSERT OR UPDATE ON public.story_highlight_items FOR EACH ROW EXECUTE FUNCTION public.story_highlight_items_owner();


--
-- Name: story_highlight_items story_highlight_items_visibility; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER story_highlight_items_visibility AFTER INSERT OR DELETE OR UPDATE ON public.story_highlight_items FOR EACH ROW EXECUTE FUNCTION public.story_links_changed();


--
-- Name: story_views story_views_set_owner; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER story_views_set_owner BEFORE INSERT OR UPDATE OF story_id, story_owner_id ON public.story_views FOR EACH ROW EXECUTE FUNCTION public.story_views_set_owner();


--
-- Name: subscriptions subscriptions_enforce; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER subscriptions_enforce BEFORE INSERT OR UPDATE ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.subscriptions_enforce();


--
-- Name: comments sync_scoping_on_comment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_scoping_on_comment AFTER INSERT OR DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.sync_scoping_on_comment();


--
-- Name: likes sync_scoping_on_like; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_scoping_on_like AFTER INSERT OR DELETE ON public.likes FOR EACH ROW EXECUTE FUNCTION public.sync_scoping_on_like();


--
-- Name: posts sync_scoping_on_post; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_scoping_on_post AFTER INSERT OR DELETE OR UPDATE OF location_lat, media ON public.posts FOR EACH ROW EXECUTE FUNCTION public.sync_scoping_on_post();


--
-- Name: profiles sync_scoping_on_profile; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_scoping_on_profile AFTER INSERT OR UPDATE OF username, full_name, avatar_url ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.sync_scoping_on_profile();


--
-- Name: subscriptions sync_scoping_on_subscription; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_scoping_on_subscription AFTER INSERT OR DELETE OR UPDATE OF status ON public.subscriptions FOR EACH ROW EXECUTE FUNCTION public.sync_scoping_on_subscription();


--
-- Name: profiles track_presence; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER track_presence BEFORE UPDATE OF last_seen_at ON public.profiles FOR EACH ROW WHEN ((new.last_seen_at IS DISTINCT FROM old.last_seen_at)) EXECUTE FUNCTION public.track_presence();


--
-- Name: profiles zz_profiles_quiet_updates; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER zz_profiles_quiet_updates BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_quiet_updates();


--
-- Name: archived_posts archived_posts_post_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archived_posts
    ADD CONSTRAINT archived_posts_post_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: archived_posts archived_posts_user_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archived_posts
    ADD CONSTRAINT archived_posts_user_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: attachments attachments_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: auth_credentials auth_credentials_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_credentials
    ADD CONSTRAINT auth_credentials_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: blocked_users blocked_users_blocked_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_blocked_fkey FOREIGN KEY (blocked_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: blocked_users blocked_users_blocker_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blocked_users
    ADD CONSTRAINT blocked_users_blocker_fkey FOREIGN KEY (blocker_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: messages check_participant; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT check_participant FOREIGN KEY (from_id, conversation_id) REFERENCES public.participants(user_id, conversation_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: comments comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: comments comments_replied_to_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_replied_to_comment_id_fkey FOREIGN KEY (replied_to_comment_id) REFERENCES public.comments(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: comments comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: conversation_reads conversation_reads_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT conversation_reads_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: conversation_reads conversation_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT conversation_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: images images_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.images
    ADD CONSTRAINT images_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: likes likes_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comments(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: likes likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: location_stories location_stories_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_stories
    ADD CONSTRAINT location_stories_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.stories(id) ON DELETE CASCADE;


--
-- Name: location_stories location_stories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.location_stories
    ADD CONSTRAINT location_stories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: messages messages_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: messages messages_reply_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_reply_message_id_fkey FOREIGN KEY (reply_message_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: messages messages_shared_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_shared_post_id_fkey FOREIGN KEY (shared_post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: messages messages_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_user_id_fkey FOREIGN KEY (from_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: notifications notifications_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: participants participants_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: participants participants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT participants_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: post_stats post_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_stats
    ADD CONSTRAINT post_stats_id_fkey FOREIGN KEY (id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: profile_presence profile_presence_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_presence
    ADD CONSTRAINT profile_presence_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: profile_stats profile_stats_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profile_stats
    ADD CONSTRAINT profile_stats_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: referrals referrals_invited_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_invited_id_fkey FOREIGN KEY (invited_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: referrals referrals_referrer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: saved_posts saved_posts_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_posts
    ADD CONSTRAINT saved_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: saved_posts saved_posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_posts
    ADD CONSTRAINT saved_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: saved_profiles saved_profiles_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_profiles
    ADD CONSTRAINT saved_profiles_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: saved_profiles saved_profiles_saver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_profiles
    ADD CONSTRAINT saved_profiles_saver_id_fkey FOREIGN KEY (saver_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: stories stories_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stories
    ADD CONSTRAINT stories_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: story_highlight_items story_highlight_items_highlight_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlight_items
    ADD CONSTRAINT story_highlight_items_highlight_id_fkey FOREIGN KEY (highlight_id) REFERENCES public.story_highlights(id) ON DELETE CASCADE;


--
-- Name: story_highlight_items story_highlight_items_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlight_items
    ADD CONSTRAINT story_highlight_items_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.stories(id) ON DELETE CASCADE;


--
-- Name: story_highlights story_highlights_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_highlights
    ADD CONSTRAINT story_highlights_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: story_likes story_likes_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.stories(id) ON DELETE CASCADE;


--
-- Name: story_likes story_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: story_views story_views_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_views
    ADD CONSTRAINT story_views_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.stories(id) ON DELETE CASCADE;


--
-- Name: story_views story_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_views
    ADD CONSTRAINT story_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: subscriptions subscriptions_subscribed_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_subscribed_to_id_fkey FOREIGN KEY (subscribed_to_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: subscriptions subscriptions_subscriber_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.subscriptions
    ADD CONSTRAINT subscriptions_subscriber_id_fkey FOREIGN KEY (subscriber_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: typing_status typing_status_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.typing_status
    ADD CONSTRAINT typing_status_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversations(id) ON DELETE CASCADE;


--
-- Name: typing_status typing_status_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.typing_status
    ADD CONSTRAINT typing_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: videos videos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_user_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: visited_regions visited_regions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visited_regions
    ADD CONSTRAINT visited_regions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: images Allow delete image only to owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow delete image only to owner." ON public.images FOR DELETE TO authenticated USING ((auth.uid() = owner_id));


--
-- Name: posts Allow delete post only to owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow delete post only to owner." ON public.posts FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: profiles Allow to create profiles for everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow to create profiles for everyone." ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: images Allow update image only to owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow update image only to owner." ON public.images FOR UPDATE TO authenticated USING ((auth.uid() = owner_id)) WITH CHECK ((auth.uid() = owner_id));


--
-- Name: posts Allow update post only to owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow update post only to owner." ON public.posts FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: images Allow upload image only to authenticated user.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow upload image only to authenticated user." ON public.images FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: posts Allow upload post only to authenticated user.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow upload post only to authenticated user." ON public.posts FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: videos Allow upload video only to authenticated user.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow upload video only to authenticated user." ON public.videos FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: archived_posts Archived posts are visible to their owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Archived posts are visible to their owner." ON public.archived_posts FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: blocked_users Blocked user can see they are blocked.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Blocked user can see they are blocked." ON public.blocked_users FOR SELECT USING ((auth.uid() = blocked_id));


--
-- Name: blocked_users Blocks are visible to their owner.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Blocks are visible to their owner." ON public.blocked_users FOR SELECT USING ((auth.uid() = blocker_id));


--
-- Name: message_reactions Delete own reaction.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Delete own reaction." ON public.message_reactions FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: conversation_reads Delete own receipt.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Delete own receipt." ON public.conversation_reads FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: typing_status Delete own typing.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Delete own typing." ON public.typing_status FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: conversations Everybody can see conversations they participate in.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Everybody can see conversations they participate in." ON public.conversations FOR SELECT USING (true);


--
-- Name: messages Everybody can see messages in the conversation.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Everybody can see messages in the conversation." ON public.messages FOR SELECT USING (true);


--
-- Name: attachments Everybody can see their messages' attachments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Everybody can see their messages' attachments." ON public.attachments FOR SELECT USING (true);


--
-- Name: participants Everybody can see their participation with conversations.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Everybody can see their participation with conversations." ON public.participants FOR SELECT USING (true);


--
-- Name: attachments Everybody can update their messages' attachments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Everybody can update their messages' attachments." ON public.attachments FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: message_reactions Insert own reaction.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert own reaction." ON public.message_reactions FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: conversation_reads Insert own receipt.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert own receipt." ON public.conversation_reads FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: typing_status Insert own typing.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Insert own typing." ON public.typing_status FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: conversations Only authentiaceted users can delete conversations they partici; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authentiaceted users can delete conversations they partici" ON public.conversations FOR DELETE TO authenticated USING (true);


--
-- Name: participants Only authentiaceted users can remove participation in conversat; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authentiaceted users can remove participation in conversat" ON public.participants FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: subscriptions Only authentiaceted users can unsubscribe from other users.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authentiaceted users can unsubscribe from other users." ON public.subscriptions FOR DELETE TO authenticated USING (((auth.uid() = subscribed_to_id) OR (auth.uid() = subscriber_id)));


--
-- Name: saved_posts Only authenticated can save posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated can save posts" ON public.saved_posts FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: comments Only authenticated can upload comments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated can upload comments." ON public.comments FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: likes Only authenticated can upload likes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated can upload likes" ON public.likes FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: attachments Only authenticated users can add attachments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can add attachments." ON public.attachments FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: stories Only authenticated users can add stories.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can add stories." ON public.stories FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: conversations Only authenticated users can create conversations with other us; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can create conversations with other us" ON public.conversations FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: messages Only authenticated users can create message in the conversation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can create message in the conversation" ON public.messages FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: messages Only authenticated users can delete their own messages in the c; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can delete their own messages in the c" ON public.messages FOR DELETE TO authenticated USING ((auth.uid() = from_id));


--
-- Name: participants Only authenticated users can participate in conversations.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can participate in conversations." ON public.participants FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: subscriptions Only authenticated users can subscribe to other users.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only authenticated users can subscribe to other users." ON public.subscriptions FOR INSERT TO authenticated WITH CHECK ((auth.uid() = subscriber_id));


--
-- Name: likes Only onwner can delete like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only onwner can delete like" ON public.likes FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: saved_posts Only owner can delete saved post; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can delete saved post" ON public.saved_posts FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: profiles Only owner can delete the profile.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can delete the profile." ON public.profiles FOR DELETE USING ((auth.uid() = id));


--
-- Name: videos Only owner can delete video.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can delete video." ON public.videos FOR DELETE TO authenticated USING ((auth.uid() = owner_id));


--
-- Name: saved_posts Only owner can see their saved posts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can see their saved posts" ON public.saved_posts FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: likes Only owner can update like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can update like" ON public.likes FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: messages Only owner can update the message.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can update the message." ON public.messages FOR UPDATE TO authenticated USING ((auth.uid() = from_id));


--
-- Name: profiles Only owner can update the profile.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can update the profile." ON public.profiles FOR UPDATE USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: videos Only owner can update video.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owner can update video." ON public.videos FOR UPDATE TO authenticated USING ((auth.uid() = owner_id)) WITH CHECK ((auth.uid() = owner_id));


--
-- Name: comments Only owners can delete comment.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owners can delete comment." ON public.comments FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: attachments Only owners can remove attachments.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owners can remove attachments." ON public.attachments FOR DELETE TO authenticated USING (true);


--
-- Name: stories Only owners can remove stories.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owners can remove stories." ON public.stories FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: comments Only owners can update comment.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owners can update comment." ON public.comments FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: stories Only owners can update stories.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Only owners can update stories." ON public.stories FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: subscriptions Owner can accept a follow request.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Owner can accept a follow request." ON public.subscriptions FOR UPDATE TO authenticated USING ((auth.uid() = subscribed_to_id)) WITH CHECK ((auth.uid() = subscribed_to_id));


--
-- Name: message_reactions Participants read reactions.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Participants read reactions." ON public.message_reactions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.participants p
  WHERE ((p.conversation_id = message_reactions.conversation_id) AND (p.user_id = auth.uid())))));


--
-- Name: conversation_reads Participants read receipts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Participants read receipts." ON public.conversation_reads FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.participants p
  WHERE ((p.conversation_id = conversation_reads.conversation_id) AND (p.user_id = auth.uid())))));


--
-- Name: typing_status Participants read typing.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Participants read typing." ON public.typing_status FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.participants p
  WHERE ((p.conversation_id = typing_status.conversation_id) AND (p.user_id = auth.uid())))));


--
-- Name: location_stories Pin own location stories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Pin own location stories" ON public.location_stories FOR INSERT WITH CHECK (((auth.uid() = user_id) AND (EXISTS ( SELECT 1
   FROM public.stories s
  WHERE ((s.id = location_stories.story_id) AND (s.user_id = auth.uid()))))));


--
-- Name: comments Post owners can delete comments on their posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Post owners can delete comments on their posts." ON public.comments FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.posts p
  WHERE ((p.id = comments.post_id) AND (p.user_id = auth.uid())))));


--
-- Name: profiles Profiles are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);


--
-- Name: referrals See own referrals; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "See own referrals" ON public.referrals FOR SELECT USING (((auth.uid() = referrer_id) OR (auth.uid() = invited_id)));


--
-- Name: location_stories Unpin own location stories; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Unpin own location stories" ON public.location_stories FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: message_reactions Update own reaction.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Update own reaction." ON public.message_reactions FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: conversation_reads Update own receipt.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Update own receipt." ON public.conversation_reads FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: typing_status Update own typing.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Update own typing." ON public.typing_status FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: archived_posts Users can archive their own posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can archive their own posts." ON public.archived_posts FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: blocked_users Users can create their own blocks.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can create their own blocks." ON public.blocked_users FOR INSERT WITH CHECK ((auth.uid() = blocker_id));


--
-- Name: blocked_users Users can remove their own blocks.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can remove their own blocks." ON public.blocked_users FOR DELETE USING ((auth.uid() = blocker_id));


--
-- Name: archived_posts Users can unarchive their own posts.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can unarchive their own posts." ON public.archived_posts FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: account_deletion_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.account_deletion_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: account_deletion_jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.account_deletion_jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: archived_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.archived_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: auth_credentials; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.auth_credentials ENABLE ROW LEVEL SECURITY;

--
-- Name: blocked_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;

--
-- Name: comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;

--
-- Name: comments comments_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comments_select ON public.comments FOR SELECT USING (((auth.uid() = user_id) OR public.can_view_author(post_owner_id)));


--
-- Name: conversation_reads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversation_reads ENABLE ROW LEVEL SECURITY;

--
-- Name: conversations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

--
-- Name: images; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.images ENABLE ROW LEVEL SECURITY;

--
-- Name: images images_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY images_select ON public.images FOR SELECT USING ((auth.uid() = owner_id));


--
-- Name: likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;

--
-- Name: likes likes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY likes_select ON public.likes FOR SELECT USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.posts p
  WHERE ((p.id = likes.post_id) AND public.can_view_author(p.user_id)))) OR (EXISTS ( SELECT 1
   FROM public.comments c
  WHERE ((c.id = likes.comment_id) AND public.can_view_author(c.post_owner_id))))));


--
-- Name: location_stories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.location_stories ENABLE ROW LEVEL SECURITY;

--
-- Name: location_stories location_stories_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY location_stories_select ON public.location_stories FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: message_reactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_select ON public.notifications FOR SELECT USING ((auth.uid() = recipient_id));


--
-- Name: participants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.participants ENABLE ROW LEVEL SECURITY;

--
-- Name: post_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: post_stats post_stats_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY post_stats_select ON public.post_stats FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

--
-- Name: posts posts_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY posts_select ON public.posts FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: profile_presence; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profile_presence ENABLE ROW LEVEL SECURITY;

--
-- Name: profile_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profile_stats ENABLE ROW LEVEL SECURITY;

--
-- Name: profile_stats profile_stats_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profile_stats_select ON public.profile_stats FOR SELECT USING (true);


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: push_outbox; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_outbox ENABLE ROW LEVEL SECURITY;

--
-- Name: referrals; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.saved_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.saved_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: saved_profiles saved_profiles_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_profiles_select ON public.saved_profiles FOR SELECT USING ((auth.uid() = saver_id));


--
-- Name: saved_profiles saved_profiles_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY saved_profiles_write ON public.saved_profiles USING ((auth.uid() = saver_id)) WITH CHECK ((auth.uid() = saver_id));


--
-- Name: stories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;

--
-- Name: stories stories_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stories_select ON public.stories FOR SELECT USING (((auth.uid() = user_id) OR ((visibility = 'public'::text) AND public.can_view_author(user_id))));


--
-- Name: story_highlight_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.story_highlight_items ENABLE ROW LEVEL SECURITY;

--
-- Name: story_highlight_items story_highlight_items_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlight_items_delete ON public.story_highlight_items FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.story_highlights h
  WHERE ((h.id = story_highlight_items.highlight_id) AND (h.user_id = auth.uid())))));


--
-- Name: story_highlight_items story_highlight_items_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlight_items_insert ON public.story_highlight_items FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM public.story_highlights h
  WHERE ((h.id = story_highlight_items.highlight_id) AND (h.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM public.stories s
  WHERE ((s.id = story_highlight_items.story_id) AND (s.user_id = auth.uid()))))));


--
-- Name: story_highlight_items story_highlight_items_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlight_items_select ON public.story_highlight_items FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: story_highlight_items story_highlight_items_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlight_items_update ON public.story_highlight_items FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.story_highlights h
  WHERE ((h.id = story_highlight_items.highlight_id) AND (h.user_id = auth.uid()))))) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.story_highlights h
  WHERE ((h.id = story_highlight_items.highlight_id) AND (h.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM public.stories s
  WHERE ((s.id = story_highlight_items.story_id) AND (s.user_id = auth.uid()))))));


--
-- Name: story_highlights; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.story_highlights ENABLE ROW LEVEL SECURITY;

--
-- Name: story_highlights story_highlights_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlights_select ON public.story_highlights FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: story_highlights story_highlights_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_highlights_write ON public.story_highlights USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: story_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.story_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: story_likes story_likes_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_likes_delete ON public.story_likes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: story_likes story_likes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_likes_insert ON public.story_likes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: story_likes story_likes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_likes_select ON public.story_likes FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: story_views; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

--
-- Name: story_views story_views_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_views_insert ON public.story_views FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: story_views story_views_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_views_select ON public.story_views FOR SELECT USING (((auth.uid() = user_id) OR (auth.uid() = story_owner_id)));


--
-- Name: subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: subscriptions subscriptions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subscriptions_select ON public.subscriptions FOR SELECT USING (((auth.uid() = subscriber_id) OR (auth.uid() = subscribed_to_id) OR ((status = 'accepted'::text) AND public.can_view_author(subscribed_to_id) AND public.can_view_author(subscriber_id))));


--
-- Name: typing_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.typing_status ENABLE ROW LEVEL SECURITY;

--
-- Name: videos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

--
-- Name: videos videos_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY videos_select ON public.videos FOR SELECT USING ((auth.uid() = owner_id));


--
-- Name: visited_regions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.visited_regions ENABLE ROW LEVEL SECURITY;

--
-- Name: visited_regions visited_regions_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY visited_regions_delete ON public.visited_regions FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: visited_regions visited_regions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY visited_regions_insert ON public.visited_regions FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: visited_regions visited_regions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY visited_regions_select ON public.visited_regions FOR SELECT USING (public.can_view_author(user_id));


--
-- Name: SCHEMA analytics; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA analytics TO analytics_ro;


--
-- Name: SCHEMA auth; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA auth TO authenticated;


--
-- Name: SCHEMA extensions; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA extensions TO authenticated;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT ALL ON SCHEMA public TO powersync;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO chat_blocks_ro;
GRANT USAGE ON SCHEMA public TO anon;


--
-- Name: SCHEMA storage; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA storage TO authenticated;


--
-- Name: FUNCTION gtrgm_in(cstring); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_in(cstring) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_out(public.gtrgm); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_out(public.gtrgm) FROM PUBLIC;


--
-- Name: FUNCTION uid(); Type: ACL; Schema: auth; Owner: -
--

GRANT ALL ON FUNCTION auth.uid() TO authenticated;


--
-- Name: FUNCTION blocked_between(a uuid, b uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.blocked_between(a uuid, b uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.blocked_between(a uuid, b uuid) TO chat_blocks_ro;


--
-- Name: FUNCTION can_view_author(p_author uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.can_view_author(p_author uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.can_view_author(p_author uuid) TO authenticated;


--
-- Name: FUNCTION chat_profile_card(p_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.chat_profile_card(p_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.chat_profile_card(p_id uuid) TO chat_blocks_ro;


--
-- Name: FUNCTION clear_posts_objects(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.clear_posts_objects() FROM PUBLIC;


--
-- Name: FUNCTION clear_stories_objects(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.clear_stories_objects() FROM PUBLIC;


--
-- Name: FUNCTION comments_fill(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.comments_fill() FROM PUBLIC;


--
-- Name: FUNCTION delete_account(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_account() FROM PUBLIC;
GRANT ALL ON FUNCTION public.delete_account() TO authenticated;


--
-- Name: FUNCTION delete_account_by_id(p_uid uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_account_by_id(p_uid uuid) FROM PUBLIC;


--
-- Name: FUNCTION delete_avatar(avatar_url text, OUT status integer, OUT content text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_avatar(avatar_url text, OUT status integer, OUT content text) FROM PUBLIC;


--
-- Name: FUNCTION delete_old_avatar(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_old_avatar() FROM PUBLIC;


--
-- Name: FUNCTION delete_old_profile(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_old_profile() FROM PUBLIC;


--
-- Name: FUNCTION delete_storage_object(bucket text, object text, OUT status integer, OUT content text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.delete_storage_object(bucket text, object text, OUT status integer, OUT content text) FROM PUBLIC;


--
-- Name: FUNCTION enqueue_push(p_recipient uuid, p_actor uuid, p_type text, p_title text, p_body text, p_data jsonb); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.enqueue_push(p_recipient uuid, p_actor uuid, p_type text, p_title text, p_body text, p_data jsonb) FROM PUBLIC;


--
-- Name: FUNCTION feed_position(p_post uuid, p_order text, p_exclude uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.feed_position(p_post uuid, p_order text, p_exclude uuid[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.feed_position(p_post uuid, p_order text, p_exclude uuid[]) TO authenticated;


--
-- Name: FUNCTION feed_post_ids(p_order text, p_exclude uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.feed_post_ids(p_order text, p_exclude uuid[]) FROM PUBLIC;


--
-- Name: FUNCTION feed_post_rows(p_ids uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.feed_post_rows(p_ids uuid[]) FROM PUBLIC;


--
-- Name: FUNCTION feed_posts(p_order text, p_limit integer, p_offset integer, p_exclude uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.feed_posts(p_order text, p_limit integer, p_offset integer, p_exclude uuid[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.feed_posts(p_order text, p_limit integer, p_offset integer, p_exclude uuid[]) TO authenticated;


--
-- Name: FUNCTION follow_list(p_user uuid, p_followers boolean, p_limit integer, p_offset integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.follow_list(p_user uuid, p_followers boolean, p_limit integer, p_offset integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.follow_list(p_user uuid, p_followers boolean, p_limit integer, p_offset integer) TO authenticated;


--
-- Name: FUNCTION gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION gin_extract_value_trgm(text, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gin_extract_value_trgm(text, internal) FROM PUBLIC;


--
-- Name: FUNCTION gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_compress(internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_compress(internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_consistent(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_decompress(internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_decompress(internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_distance(internal, text, smallint, oid, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_options(internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_options(internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_penalty(internal, internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_penalty(internal, internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_picksplit(internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_picksplit(internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_same(public.gtrgm, public.gtrgm, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_same(public.gtrgm, public.gtrgm, internal) FROM PUBLIC;


--
-- Name: FUNCTION gtrgm_union(internal, internal); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.gtrgm_union(internal, internal) FROM PUBLIC;


--
-- Name: FUNCTION handle_delete_post_media(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_delete_post_media() FROM PUBLIC;


--
-- Name: FUNCTION handle_delete_story_media(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_delete_story_media() FROM PUBLIC;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;


--
-- Name: FUNCTION handle_update_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_update_user() FROM PUBLIC;


--
-- Name: FUNCTION media_in_use(p_url text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.media_in_use(p_url text) FROM PUBLIC;


--
-- Name: FUNCTION media_object_key(p_url text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.media_object_key(p_url text) FROM PUBLIC;


--
-- Name: FUNCTION notifications_keep(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.notifications_keep() FROM PUBLIC;


--
-- Name: FUNCTION notifications_prune(p_recipient uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.notifications_prune(p_recipient uuid) FROM PUBLIC;


--
-- Name: FUNCTION notify_push_outbox(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.notify_push_outbox() FROM PUBLIC;


--
-- Name: FUNCTION pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time double precision, OUT blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.pg_stat_statements(showtext boolean, OUT userid oid, OUT dbid oid, OUT toplevel boolean, OUT queryid bigint, OUT query text, OUT plans bigint, OUT total_plan_time double precision, OUT min_plan_time double precision, OUT max_plan_time double precision, OUT mean_plan_time double precision, OUT stddev_plan_time double precision, OUT calls bigint, OUT total_exec_time double precision, OUT min_exec_time double precision, OUT max_exec_time double precision, OUT mean_exec_time double precision, OUT stddev_exec_time double precision, OUT rows bigint, OUT shared_blks_hit bigint, OUT shared_blks_read bigint, OUT shared_blks_dirtied bigint, OUT shared_blks_written bigint, OUT local_blks_hit bigint, OUT local_blks_read bigint, OUT local_blks_dirtied bigint, OUT local_blks_written bigint, OUT temp_blks_read bigint, OUT temp_blks_written bigint, OUT blk_read_time double precision, OUT blk_write_time double precision, OUT temp_blk_read_time double precision, OUT temp_blk_write_time double precision, OUT wal_records bigint, OUT wal_fpi bigint, OUT wal_bytes numeric, OUT jit_functions bigint, OUT jit_generation_time double precision, OUT jit_inlining_count bigint, OUT jit_inlining_time double precision, OUT jit_optimization_count bigint, OUT jit_optimization_time double precision, OUT jit_emission_count bigint, OUT jit_emission_time double precision) FROM PUBLIC;


--
-- Name: FUNCTION pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.pg_stat_statements_info(OUT dealloc bigint, OUT stats_reset timestamp with time zone) FROM PUBLIC;


--
-- Name: FUNCTION post_by_id(p_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.post_by_id(p_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.post_by_id(p_id uuid) TO authenticated;


--
-- Name: FUNCTION post_likers(p_post uuid, p_limit integer, p_offset integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.post_likers(p_post uuid, p_limit integer, p_offset integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.post_likers(p_post uuid, p_limit integer, p_offset integer) TO authenticated;


--
-- Name: FUNCTION post_likers_in_followings(p_posts uuid[], p_per_post integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.post_likers_in_followings(p_posts uuid[], p_per_post integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.post_likers_in_followings(p_posts uuid[], p_per_post integer) TO authenticated;


--
-- Name: FUNCTION post_thumb(p_media text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.post_thumb(p_media text) FROM PUBLIC;


--
-- Name: FUNCTION posts_refresh_referral_tier(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.posts_refresh_referral_tier() FROM PUBLIC;


--
-- Name: FUNCTION profile_cards(p_ids uuid[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.profile_cards(p_ids uuid[]) FROM PUBLIC;
GRANT ALL ON FUNCTION public.profile_cards(p_ids uuid[]) TO authenticated;


--
-- Name: FUNCTION profiles_quiet_updates(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.profiles_quiet_updates() FROM PUBLIC;


--
-- Name: FUNCTION push_actor_name(p_actor uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.push_actor_name(p_actor uuid) FROM PUBLIC;


--
-- Name: FUNCTION queue_media_deletion(p_urls text[]); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.queue_media_deletion(p_urls text[]) FROM PUBLIC;


--
-- Name: FUNCTION redeem_referral(p_handle text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.redeem_referral(p_handle text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.redeem_referral(p_handle text) TO authenticated;


--
-- Name: FUNCTION referrals_refresh_referrer(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.referrals_refresh_referrer() FROM PUBLIC;


--
-- Name: FUNCTION refresh_referral_tier(p_user uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.refresh_referral_tier(p_user uuid) FROM PUBLIC;


--
-- Name: FUNCTION refresh_story_visibility(p_story uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.refresh_story_visibility(p_story uuid) FROM PUBLIC;


--
-- Name: FUNCTION saved_posts_page(p_limit integer, p_offset integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.saved_posts_page(p_limit integer, p_offset integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.saved_posts_page(p_limit integer, p_offset integer) TO authenticated;


--
-- Name: FUNCTION search_key(p text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.search_key(p text) FROM PUBLIC;


--
-- Name: FUNCTION search_profiles(p_query text, p_limit integer, p_offset integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.search_profiles(p_query text, p_limit integer, p_offset integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.search_profiles(p_query text, p_limit integer, p_offset integer) TO authenticated;


--
-- Name: FUNCTION server_created_at(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.server_created_at() FROM PUBLIC;


--
-- Name: FUNCTION set_limit(real); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.set_limit(real) FROM PUBLIC;


--
-- Name: FUNCTION show_limit(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.show_limit() FROM PUBLIC;


--
-- Name: FUNCTION show_trgm(text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.show_trgm(text) FROM PUBLIC;


--
-- Name: FUNCTION similarity(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.similarity(text, text) FROM PUBLIC;


--
-- Name: FUNCTION similarity_dist(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.similarity_dist(text, text) FROM PUBLIC;


--
-- Name: FUNCTION similarity_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.similarity_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION stories_server_times(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stories_server_times() FROM PUBLIC;


--
-- Name: FUNCTION stories_set_visibility(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.stories_set_visibility() FROM PUBLIC;


--
-- Name: FUNCTION story_by_id(p_id uuid); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.story_by_id(p_id uuid) FROM PUBLIC;
GRANT ALL ON FUNCTION public.story_by_id(p_id uuid) TO authenticated;


--
-- Name: FUNCTION story_highlight_items_owner(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.story_highlight_items_owner() FROM PUBLIC;


--
-- Name: FUNCTION story_links_changed(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.story_links_changed() FROM PUBLIC;


--
-- Name: FUNCTION story_views_set_owner(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.story_views_set_owner() FROM PUBLIC;


--
-- Name: FUNCTION story_visibility(p_id uuid, p_expires_at timestamp with time zone); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.story_visibility(p_id uuid, p_expires_at timestamp with time zone) FROM PUBLIC;


--
-- Name: FUNCTION strict_word_similarity(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.strict_word_similarity(text, text) FROM PUBLIC;


--
-- Name: FUNCTION strict_word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_commutator_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION strict_word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION strict_word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_dist_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION strict_word_similarity_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.strict_word_similarity_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION subscriptions_enforce(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.subscriptions_enforce() FROM PUBLIC;


--
-- Name: FUNCTION suggested_profiles(p_limit integer); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.suggested_profiles(p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION public.suggested_profiles(p_limit integer) TO authenticated;


--
-- Name: FUNCTION sync_scoping_on_comment(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_scoping_on_comment() FROM PUBLIC;


--
-- Name: FUNCTION sync_scoping_on_like(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_scoping_on_like() FROM PUBLIC;


--
-- Name: FUNCTION sync_scoping_on_post(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_scoping_on_post() FROM PUBLIC;


--
-- Name: FUNCTION sync_scoping_on_profile(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_scoping_on_profile() FROM PUBLIC;


--
-- Name: FUNCTION sync_scoping_on_subscription(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.sync_scoping_on_subscription() FROM PUBLIC;


--
-- Name: FUNCTION track_presence(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.track_presence() FROM PUBLIC;


--
-- Name: FUNCTION trg_push_on_comment(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_push_on_comment() FROM PUBLIC;


--
-- Name: FUNCTION trg_push_on_like(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_push_on_like() FROM PUBLIC;


--
-- Name: FUNCTION trg_push_on_subscription(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.trg_push_on_subscription() FROM PUBLIC;


--
-- Name: FUNCTION word_similarity(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.word_similarity(text, text) FROM PUBLIC;


--
-- Name: FUNCTION word_similarity_commutator_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.word_similarity_commutator_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION word_similarity_dist_commutator_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.word_similarity_dist_commutator_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION word_similarity_dist_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.word_similarity_dist_op(text, text) FROM PUBLIC;


--
-- Name: FUNCTION word_similarity_op(text, text); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.word_similarity_op(text, text) FROM PUBLIC;


--
-- Name: TABLE profile_presence; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.profile_presence TO powersync;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.profiles TO powersync;
GRANT REFERENCES,TRIGGER,TRUNCATE ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.id; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(id) ON TABLE public.profiles TO authenticated;
GRANT SELECT(id) ON TABLE public.profiles TO anon;


--
-- Name: COLUMN profiles.full_name; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(full_name),UPDATE(full_name) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.username; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(username),UPDATE(username) ON TABLE public.profiles TO authenticated;
GRANT SELECT(username) ON TABLE public.profiles TO anon;


--
-- Name: COLUMN profiles.avatar_url; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(avatar_url),UPDATE(avatar_url) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.push_token; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(push_token) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.referral_tier; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(referral_tier) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.bio; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(bio),UPDATE(bio) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.birthday; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(birthday) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.telegram; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(telegram),UPDATE(telegram) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.website; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(website),UPDATE(website) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.instagram; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(instagram),UPDATE(instagram) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.gender; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(gender) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.is_private; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(is_private),UPDATE(is_private) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.onboarded_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(onboarded_at),UPDATE(onboarded_at) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.referral_tier_expires_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(referral_tier_expires_at) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.notifications_seen_at; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT(notifications_seen_at),UPDATE(notifications_seen_at) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.last_seen_at; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(last_seen_at) ON TABLE public.profiles TO authenticated;


--
-- Name: COLUMN profiles.lang; Type: ACL; Schema: public; Owner: -
--

GRANT UPDATE(lang) ON TABLE public.profiles TO authenticated;


--
-- Name: TABLE active_users; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.active_users TO analytics_ro;


--
-- Name: TABLE activity; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.activity TO analytics_ro;


--
-- Name: TABLE blocked_users; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.blocked_users TO powersync;
GRANT ALL ON TABLE public.blocked_users TO authenticated;


--
-- Name: TABLE blocked; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.blocked TO analytics_ro;


--
-- Name: TABLE comments; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.comments TO powersync;
GRANT ALL ON TABLE public.comments TO authenticated;


--
-- Name: TABLE comments; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.comments TO analytics_ro;


--
-- Name: TABLE conversations; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.conversations TO powersync;


--
-- Name: TABLE conversations; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.conversations TO analytics_ro;


--
-- Name: TABLE daily_active; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.daily_active TO analytics_ro;


--
-- Name: TABLE subscriptions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.subscriptions TO powersync;
GRANT ALL ON TABLE public.subscriptions TO authenticated;


--
-- Name: TABLE follows; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.follows TO analytics_ro;


--
-- Name: TABLE story_highlights; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.story_highlights TO powersync;
GRANT ALL ON TABLE public.story_highlights TO authenticated;


--
-- Name: TABLE highlights; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.highlights TO analytics_ro;


--
-- Name: TABLE likes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.likes TO powersync;
GRANT ALL ON TABLE public.likes TO authenticated;


--
-- Name: TABLE messages; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.messages TO powersync;


--
-- Name: TABLE posts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.posts TO powersync;
GRANT ALL ON TABLE public.posts TO authenticated;


--
-- Name: TABLE referrals; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.referrals TO powersync;
GRANT SELECT,REFERENCES,TRIGGER ON TABLE public.referrals TO authenticated;


--
-- Name: TABLE stories; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.stories TO powersync;
GRANT ALL ON TABLE public.stories TO authenticated;


--
-- Name: TABLE kpis; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.kpis TO analytics_ro;


--
-- Name: TABLE likes; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.likes TO analytics_ro;


--
-- Name: TABLE messages; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.messages TO analytics_ro;


--
-- Name: TABLE posts; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.posts TO analytics_ro;


--
-- Name: TABLE push_outbox; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.push_outbox TO powersync;


--
-- Name: TABLE push; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.push TO analytics_ro;


--
-- Name: TABLE referral_counts; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.referral_counts TO analytics_ro;


--
-- Name: TABLE referrals; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.referrals TO analytics_ro;


--
-- Name: TABLE saved_posts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.saved_posts TO powersync;
GRANT ALL ON TABLE public.saved_posts TO authenticated;


--
-- Name: TABLE saves; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.saves TO analytics_ro;


--
-- Name: TABLE auth_credentials; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.auth_credentials TO powersync;


--
-- Name: TABLE signups; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.signups TO analytics_ro;


--
-- Name: TABLE stories; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.stories TO analytics_ro;


--
-- Name: TABLE story_views; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.story_views TO powersync;
GRANT ALL ON TABLE public.story_views TO authenticated;


--
-- Name: TABLE story_view_events; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.story_view_events TO analytics_ro;


--
-- Name: TABLE story_views; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.story_views TO analytics_ro;


--
-- Name: TABLE visited_regions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.visited_regions TO powersync;
GRANT ALL ON TABLE public.visited_regions TO authenticated;


--
-- Name: TABLE users; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.users TO analytics_ro;


--
-- Name: TABLE visited_regions; Type: ACL; Schema: analytics; Owner: -
--

GRANT SELECT ON TABLE analytics.visited_regions TO analytics_ro;


--
-- Name: TABLE account_deletion_codes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.account_deletion_codes TO powersync;


--
-- Name: TABLE account_deletion_jobs; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.account_deletion_jobs TO powersync;


--
-- Name: TABLE archived_posts; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.archived_posts TO powersync;
GRANT ALL ON TABLE public.archived_posts TO authenticated;


--
-- Name: TABLE attachments; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.attachments TO powersync;


--
-- Name: TABLE auth_codes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.auth_codes TO powersync;


--
-- Name: TABLE conversation_reads; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.conversation_reads TO powersync;


--
-- Name: TABLE images; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.images TO powersync;
GRANT ALL ON TABLE public.images TO authenticated;


--
-- Name: TABLE location_stories; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.location_stories TO powersync;
GRANT ALL ON TABLE public.location_stories TO authenticated;


--
-- Name: TABLE media_deletion_queue; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.media_deletion_queue TO powersync;


--
-- Name: TABLE message_reactions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.message_reactions TO powersync;


--
-- Name: TABLE notifications; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.notifications TO powersync;
GRANT SELECT ON TABLE public.notifications TO authenticated;


--
-- Name: TABLE participants; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.participants TO powersync;


--
-- Name: TABLE post_stats; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.post_stats TO powersync;
GRANT SELECT ON TABLE public.post_stats TO authenticated;


--
-- Name: TABLE profile_stats; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.profile_stats TO powersync;
GRANT SELECT ON TABLE public.profile_stats TO authenticated;


--
-- Name: TABLE saved_profiles; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.saved_profiles TO powersync;
GRANT ALL ON TABLE public.saved_profiles TO authenticated;


--
-- Name: TABLE story_highlight_items; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.story_highlight_items TO powersync;
GRANT ALL ON TABLE public.story_highlight_items TO authenticated;


--
-- Name: TABLE story_likes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.story_likes TO powersync;
GRANT ALL ON TABLE public.story_likes TO authenticated;


--
-- Name: TABLE typing_status; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.typing_status TO powersync;


--
-- Name: TABLE videos; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT ON TABLE public.videos TO powersync;
GRANT ALL ON TABLE public.videos TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: analytics; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE treepnet IN SCHEMA analytics GRANT SELECT ON TABLES TO analytics_ro;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE treepnet IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE treepnet IN SCHEMA public GRANT SELECT ON TABLES TO powersync;
ALTER DEFAULT PRIVILEGES FOR ROLE treepnet IN SCHEMA public GRANT ALL ON TABLES TO authenticated;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE treepnet REVOKE ALL ON FUNCTIONS FROM PUBLIC;


--
-- PostgreSQL database dump complete
--



-- Remove the old PowerSync chat from the server, for good (step 2 of 2).
--
-- APPLY ONLY once the app version without the old chat is in the stores (see
-- lock_legacy_chat.sql, step 1: the tables are already empty and closed).
--
-- Direct messages moved to the self-hosted chat server (lib/chat) and its own
-- database; PowerSync stopped syncing the old chat tables on 2026-10-10. The
-- tables were still there and still open to every signed-in user over the
-- REST API — anyone could read every old private message, delete any
-- conversation, or add a message to one — and the push_on_message trigger
-- turned such a message into a real push notification to the other people
-- in it. Their content was test data only, not wanted (2026-11-01).
--
-- Also takes the old chat out of what still referred to it: account deletion
-- (delete_account_by_id) and the admin panel's analytics views.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet --     -v ON_ERROR_STOP=1 < drop_legacy_chat.sql
-- Not undoable (only from a backup).

begin;

-- Account deletion without the old chat tables.
CREATE OR REPLACE FUNCTION public.delete_account_by_id(p_uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

-- Admin analytics: the old chat's counts and views go (the panel never read
-- them). kpis is rebuilt without total_messages.
drop view analytics.kpis;
create view analytics.kpis as
SELECT ( SELECT count(*) AS count
           FROM profiles) AS total_users,
    ( SELECT count(*) AS count
           FROM posts) AS total_posts,
    ( SELECT count(*) AS count
           FROM stories) AS total_stories,
    ( SELECT count(*) AS count
           FROM comments) AS total_comments,
    ( SELECT count(*) AS count
           FROM likes) AS total_likes,
    ( SELECT count(*) AS count
           FROM subscriptions) AS total_follows,
    ( SELECT count(*) AS count
           FROM referrals) AS total_referrals;
grant select on analytics.kpis to analytics_ro;
drop view analytics.messages;
drop view analytics.conversations;

-- (Its push trigger went in step 1.)
drop trigger if exists push_on_message on public.messages;
drop function if exists public.trg_push_on_message();

-- The old chat itself.
drop table public.message_reactions,
           public.conversation_reads,
           public.typing_status,
           public.attachments,
           public.messages,
           public.participants,
           public.conversations;

commit;

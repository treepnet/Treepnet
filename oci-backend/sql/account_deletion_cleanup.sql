-- Delete an account completely, from both the app and the website.
--
-- Before: the app (delete_account) and the website (delete_account_by_id) each
-- had their own copy of the deletion and removed only the main-database rows.
-- What lived elsewhere stayed: the Firebase sign-in (app path), the user's chats
-- on the chat server with their files, their photos in object storage, push
-- texts in push_outbox, activity minutes in analytics, verification codes, and
-- legacy chat conversations (the peer's side). The website's code cleanup also
-- ran after the profile was gone, so it never matched.
--
-- After: delete_account() is a thin wrapper over delete_account_by_id(), which
--   * collects the account's media URLs before the rows go,
--   * deletes everything the account owns or is part of in this database,
--     legacy chat conversations included (both sides),
--   * queues an account_deletion_jobs row. The delete-account service's worker
--     (functions/delete-account/cleanup.js) picks it up within ~30 s, deletes
--     the Firebase user, the chat-server user with every conversation they were
--     in (both sides, with files), and the media files, retrying until each step
--     succeeds, then deletes the job row.
--
-- Undo: account_deletion_cleanup_rollback.sql restores the previous functions.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < account_deletion_cleanup.sql

begin;

create table if not exists public.account_deletion_jobs (
  id bigserial primary key,
  user_id uuid not null,
  -- Object-storage URLs of the account's photos, collected before deletion.
  media text[] not null default '{}',
  created_at timestamptz not null default now(),
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_error text,
  -- Steps already finished (firebase, chat, media), so a retry skips them.
  done_steps text[] not null default '{}'
);
alter table public.account_deletion_jobs enable row level security;
revoke all on table public.account_deletion_jobs from public, authenticated;
revoke all on sequence public.account_deletion_jobs_id_seq from public, authenticated;

create or replace function public.delete_account_by_id(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
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

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
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

-- Leftovers of accounts deleted before this change.
delete from push_outbox o
 where not exists (select 1 from profiles p where p.id = o.recipient_id)
    or (o.actor_id is not null
        and not exists (select 1 from profiles p where p.id = o.actor_id));
delete from conversations c
 where not exists (select 1 from participants pa where pa.conversation_id = c.id);

commit;

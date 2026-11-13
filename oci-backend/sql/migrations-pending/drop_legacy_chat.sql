-- Remove the old PowerSync chat from the server, for good (step 2 of 2).
-- PENDING: not applied. To apply, copy it into migrations/ as the next
-- NNN_drop_legacy_chat.sql and run ./migrate.sh --dry-run, then ./migrate.sh.
-- Not undoable (only from a backup).
--
-- APPLY ONLY once no phone needs the old chat (lock_legacy_chat.sql, step 1,
-- already emptied and closed the tables). It also changes the admin panel's
-- analytics views (the old chat's two views go; kpis loses total_messages),
-- so apply it when the admin panel is being looked at too.
--
-- Direct messages moved to the self-hosted chat server (lib/chat) and its own
-- database; PowerSync stopped syncing the old chat tables on 2026-10-10. The
-- tables were still there and still open to every signed-in user over the
-- REST API — anyone could read every old private message, delete any
-- conversation, or add a message to one — and the push_on_message trigger
-- turned such a message into a real push notification to the other people
-- in it. Their content was test data only, not wanted (2026-11-01).
--
-- This was a loose file with its own BEGIN/COMMIT and a full copy of
-- delete_account_by_id as of 2026-11-01; migrations 004, 011 and 012 changed
-- that function since, and the copy would have undone them. Now it takes the
-- old-chat lines out of the function as it is when this runs, and stops if
-- those lines, or the kpis view, are no longer what it expects.

-- Account deletion without the old chat tables.
do $migration$
declare
  v_def text := pg_get_functiondef('public.delete_account_by_id'::regproc);
  v_new text;
begin
  v_new := replace(v_def, $blk$  -- Legacy chat: every conversation the account was in, both sides (messages,
  -- attachments, reactions, participants and reads go with it).
  delete from conversations         where id in
      (select conversation_id from participants where user_id = p_uid);
  delete from attachments           where message_id in
      (select id from messages where from_id = p_uid);
  delete from messages              where from_id = p_uid;
  delete from participants          where user_id = p_uid;

$blk$, '');
  if v_new = v_def then
    raise exception 'delete_account_by_id no longer has the old-chat lines this file removes: update the file';
  end if;
  if v_new ~ '\m(messages|conversations|participants|attachments)\M' then
    raise exception 'delete_account_by_id still names an old chat table: update the file';
  end if;
  execute v_new;
end
$migration$;

-- Admin analytics: the old chat's views go (the panel never read them), and
-- kpis is rebuilt without total_messages — if it is still the view this file
-- was written against.
do $migration$
begin
  if md5(pg_get_viewdef('analytics.kpis'::regclass)) <> '542c74f5d8fcb15247b555226f6831b1' then
    raise exception 'analytics.kpis changed since this file was written: update the file';
  end if;
end
$migration$;
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

-- ============================================================================
-- Web "Delete account" backend (treepnet.com/delete-account + Azure Function)
-- ----------------------------------------------------------------------------
-- The website can't authenticate as the user, so deletion runs server-side from
-- an Azure Function that connects with an admin/service DB user. This file adds:
--   1) account_deletion_codes — one-time email codes with expiry.
--   2) delete_account_by_id(p_uid) — the SAME cascade as delete_account(), but
--      by a passed-in id instead of auth.uid(). Called only by the Function.
-- Apply once against Azure Postgres (like the other sql/ files).
-- ============================================================================

-- 1) One-time confirmation codes ---------------------------------------------
create table if not exists public.account_deletion_codes (
  email       text primary key,
  code        text        not null,
  expires_at  timestamptz not null,
  attempts    int         not null default 0,
  created_at  timestamptz not null default now()
);

-- 2) Delete by id (mirror of delete_account(), parametrised) ------------------
create or replace function public.delete_account_by_id(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_uid is null then
    raise exception 'missing user id';
  end if;

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

  -- Chat
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

  -- The profile row itself
  delete from profiles              where id = p_uid;

  -- Clean up any pending delete code for this account.
  delete from public.account_deletion_codes
    where email = (select email from profiles where id = p_uid);
end;
$$;

-- Only the service role the Azure Function connects as may run these.
-- (If the Function uses the DB admin/owner directly, these grants are a no-op
-- safety net. Replace `powersync_role` with the service role you actually use.)
revoke all on function public.delete_account_by_id(uuid) from public;
-- grant execute on function public.delete_account_by_id(uuid) to powersync_role;

-- PostgREST schema cache reload (harmless if not using PostgREST for this):
notify pgrst, 'reload schema';

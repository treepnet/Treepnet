-- Undoes account_deletion_cleanup.sql: restores the two deletion functions as
-- they were before (main-database rows only, no cleanup job). The
-- account_deletion_jobs table is left in place so queued jobs aren't lost; stop
-- the worker by redeploying the previous delete-account service if needed.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < account_deletion_cleanup_rollback.sql

begin;

CREATE OR REPLACE FUNCTION public.delete_account_by_id(p_uid uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;


CREATE OR REPLACE FUNCTION public.delete_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  -- ID ustunlari uuid tipida (mavjud RLS'lar `auth.uid() = user_id`ni to'g'ridan
  -- to'g'ri ishlatadi). Shuning uchun v_uid ham uuid bo'lishi shart — aks holda
  -- `uuid = text` xatosi (42883) chiqadi.
  v_uid uuid := auth.uid();   -- JWT sub. RLS ham shu qoidada: auth.uid() = sub
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Story bog'liqliklari (avval bolalar, keyin story)
  delete from story_likes          where user_id = v_uid;
  delete from story_views          where user_id = v_uid;
  delete from story_highlight_items where highlight_id in
      (select id from story_highlights where user_id = v_uid);
  delete from story_highlights     where user_id = v_uid;
  delete from location_stories     where user_id = v_uid;
  delete from stories              where user_id = v_uid;

  -- Post bog'liqliklari
  delete from likes                where user_id = v_uid;
  delete from comments             where user_id = v_uid;
  delete from saved_posts          where user_id = v_uid;
  delete from archived_posts       where user_id = v_uid;
  delete from images               where owner_id = v_uid;
  delete from videos               where owner_id = v_uid;
  delete from posts                where user_id = v_uid;

  -- Chat: foydalanuvchi xabarlari, attachmentlari, ishtirokchiligi
  delete from attachments          where message_id in
      (select id from messages where from_id = v_uid);
  delete from messages             where from_id = v_uid;
  delete from participants         where user_id = v_uid;

  -- Ijtimoiy graf va boshqalar
  delete from subscriptions        where subscriber_id = v_uid
                                       or subscribed_to_id = v_uid;
  delete from blocked_users        where blocker_id = v_uid
                                       or blocked_id = v_uid;
  delete from referrals            where referrer_id = v_uid
                                       or invited_id = v_uid;
  delete from saved_profiles       where saver_id = v_uid;
  delete from visited_regions      where user_id = v_uid;

  -- Nihoyat profil qatorining o'zi
  delete from profiles             where id = v_uid;

  -- (Ixtiyoriy) Entra o'chirishni backend job'i uchun navbatga qo'yish.
  -- Buning uchun oldin shu jadvalni yarating:
  --   create table if not exists account_deletion_requests(
  --     user_id text primary key, requested_at timestamptz default now());
  -- insert into account_deletion_requests(user_id) values (v_uid)
  --   on conflict do nothing;
end;
$function$;


commit;

-- ============================================================================
-- delete_account()  —  #7 "Delete Account" uchun backend funksiyasi
-- ----------------------------------------------------------------------------
-- Ilova (settings_page.dart) parolni qayta tekshirgach shu RPC'ni chaqiradi:
--     await postgrest().rpc('delete_account');
-- Funksiya JWT'dagi `sub` (= auth.uid()) orqali joriy foydalanuvchini aniqlaydi
-- va unga tegishli HAMMA qatorni bazadan o'chiradi. Argument olmaydi.
--
-- MUHIM: bu faqat POSTGRES bazasini tozalaydi. Entra (Azure AD) dagi shaxsni
-- (login identity) o'chirish uchun Microsoft Graph API kerak — pastdagi izohga
-- qarang. SQL bilan Entra hisobini o'chirib bo'lmaydi.
--
-- Ishga tushirishdan oldin: har bir jadval nomi/ustuni o'z bazangizga mos
-- kelishini tekshiring (quyidagilar PowerSync schema.dart asosida yozilgan).
-- ============================================================================

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;

-- Faqat autentifikatsiya qilingan (login qilgan) rollar chaqira olsin:
revoke all on function public.delete_account() from public;
grant execute on function public.delete_account() to authenticated;   -- rol nomi o'zgarishi mumkin (powersync_role va h.k.)

-- PostgREST sxema keshini yangilash:
notify pgrst, 'reload schema';

-- ============================================================================
-- Entra (Azure AD) shaxsini o'chirish — SQL emas, backend kerak
-- ----------------------------------------------------------------------------
-- "Hatto Entra'dan ham 100% o'chsin" talabi uchun ishonchli backend (masalan
-- Azure Function yoki PowerSync backend connector) Microsoft Graph orqali:
--     DELETE https://graph.microsoft.com/v1.0/users/{entra-object-id}
-- chaqirishi kerak (application permission: User.ReadWrite.All). Buni yuqoridagi
-- account_deletion_requests navbatini kuzatuvchi job qilishi mumkin.
-- Client'dan to'g'ridan-to'g'ri Graph'ni chaqirmang — admin maxfiy kalit ochilib
-- qoladi.
-- ============================================================================

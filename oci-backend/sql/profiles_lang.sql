-- The app language of each user, so push notifications can be written in it.
--
-- Like, comment and follow pushes were always English ("liked your post"):
-- nothing on the server knew which language a user reads the app in. The app
-- now stores it here ('en' or 'ru'; null = not reported yet, sent as English)
-- and the push worker words the notification in it. Users may update it on
-- their own profile only (the column joins the update grant from
-- profiles_write_columns.sql); it isn't synced to other devices.
--
-- Undo: revoke update (lang) on public.profiles from authenticated;
--       alter table public.profiles drop column lang;

begin;

alter table public.profiles add column if not exists lang text
  check (lang in ('en', 'ru'));
grant update (lang) on table public.profiles to authenticated;

commit;

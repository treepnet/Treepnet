-- Adds the profile "About"/bio text column. Idempotent — safe to re-run.
-- PowerSync mirrors public.profiles, so once this column exists the app can
-- read and write bio directly (see DatabaseClient.updateUserBio).
alter table public.profiles
  add column if not exists bio text;

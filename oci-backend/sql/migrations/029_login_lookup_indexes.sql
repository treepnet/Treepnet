-- Login, sign-up, password reset and the web account deletion find a person
-- by lower(email) or lower(username) (auth-service, delete-account). The
-- unique indexes are on the plain columns, so each of those read the whole
-- profiles table. These are on what the lookups ask for; no code changes.
--
-- Unique as well: two accounts whose emails differ only in case (one mailbox)
-- can't exist. Every stored email and username was lowercase already (70 of
-- 70, no clashes, 2026-11-13); usernames are kept lowercase by a check.

create unique index if not exists profiles_email_lower_key
  on public.profiles (lower(email));

create unique index if not exists profiles_username_lower_key
  on public.profiles (lower(username));

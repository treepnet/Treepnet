-- Usernames: lower-case only, and never two accounts with the same one.
--
-- Before: sign-up checked that a username was free, but changing it in the
-- profile didn't, and nothing in the database stopped duplicates — so two
-- accounts could share a username, and signing in or an invite link by
-- username picked one of them at random. Nothing stopped capital letters
-- either, outside the app.
--
-- After: a username may hold only lower-case letters, digits, `_` and `.`
-- (as the app and sign-up already require), and it is unique. Because it is
-- lower-case only, plain uniqueness is also case-insensitive. A change to a
-- taken username is refused (23505); the app checks before saving and says so.
-- Checked first on prod: 86 usernames, none breaking the rule, no duplicates.
--
-- Undo: username_unique_lowercase_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < username_unique_lowercase.sql

begin;

alter table public.profiles
  add constraint username_format check (username ~ '^[a-z0-9_.]+$');
create unique index profiles_username_key on public.profiles (username);

commit;

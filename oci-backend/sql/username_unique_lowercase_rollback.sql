-- Undoes username_unique_lowercase.sql. Only for an emergency.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < username_unique_lowercase_rollback.sql

begin;

drop index if exists public.profiles_username_key;
alter table public.profiles drop constraint if exists username_format;

commit;

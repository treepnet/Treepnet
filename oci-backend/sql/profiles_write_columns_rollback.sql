-- Undoes profiles_write_columns.sql: app users can insert, update every column
-- of, and delete their own profile again. Only for an emergency.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < profiles_write_columns_rollback.sql

begin;

revoke update (
  full_name, username, avatar_url, push_token, bio, birthday, gender,
  telegram, website, instagram, is_private, onboarded_at,
  notifications_seen_at, last_seen_at
) on table public.profiles from authenticated;
grant insert, update, delete on table public.profiles to authenticated;

commit;

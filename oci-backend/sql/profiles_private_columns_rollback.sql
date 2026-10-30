-- Undoes profiles_private_columns.sql: app users can read every profile
-- column again. Only for an emergency.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < profiles_private_columns_rollback.sql

begin;

revoke select (
  id, full_name, username, avatar_url, referral_tier, referral_tier_expires_at,
  bio, is_private, telegram, website, instagram, onboarded_at,
  notifications_seen_at
) on table public.profiles from authenticated;
grant select on table public.profiles to authenticated;

commit;

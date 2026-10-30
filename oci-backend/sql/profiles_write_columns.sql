-- Limit what app users can write in their own profile.
--
-- Before: `authenticated` held table-wide INSERT, UPDATE and DELETE on
-- profiles, so through the API a user could give themselves the top travel
-- badge forever (referral_tier / referral_tier_expires_at), switch the email
-- used for sign-in and password reset without confirming it, or delete their
-- own row and insert it again with someone else's email or username — so the
-- real owner could no longer sign up.
--
-- After: profiles are created and deleted only by the server (auth-service
-- signs up as the table owner; delete_account() / delete_account_by_id() are
-- SECURITY DEFINER). App users may update only the columns the app edits;
-- email and the badge are changed by the server alone (refresh_referral_tier
-- and handle_update_user are SECURITY DEFINER, so they keep working).
--
-- Undo: profiles_write_columns_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < profiles_write_columns.sql

begin;

revoke insert, update, delete on table public.profiles from authenticated;
grant update (
  full_name, username, avatar_url, push_token, bio, birthday, gender,
  telegram, website, instagram, is_private, onboarded_at,
  notifications_seen_at, last_seen_at
) on table public.profiles to authenticated;

commit;

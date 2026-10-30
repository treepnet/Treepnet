-- Stop the public API exposing private profile fields.
--
-- Before: `authenticated` — which is also PostgREST's anonymous role — could
-- read every column of `profiles`, so anyone, logged in or not, could list
-- every user's email, birthday, gender, push token and last-seen through
-- /profiles. (The matching sync-rule change stops them reaching other people's
-- phones: global_profiles / user_own_profile in powersync/sync-config.yaml.)
--
-- After: app users can read only the public columns. Writes are unchanged
-- (table-level UPDATE stays), and the app never reads the private columns
-- through the API: its own come through PowerSync (`my_profile`). PostgREST
-- updates send no `Prefer: return=representation`, so no RETURNING needs the
-- hidden columns. The auth, delete-account and push services connect as the
-- owner; PowerSync reads as `powersync` — neither is affected.
--
-- Undo: profiles_private_columns_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < profiles_private_columns.sql

begin;

revoke select on table public.profiles from authenticated;
grant select (
  id, full_name, username, avatar_url, referral_tier, referral_tier_expires_at,
  bio, is_private, telegram, website, instagram, onboarded_at,
  notifications_seen_at
) on table public.profiles to authenticated;

commit;

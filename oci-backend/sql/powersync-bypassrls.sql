-- PowerSync replication role must bypass RLS.
--
-- Whenever the sync rules change, PowerSync creates a new sync-rules version and
-- re-reads every table with a plain SELECT (initial snapshot). Unlike the WAL
-- stream, that SELECT is subject to row-level security, and the replication
-- role has no auth.uid() — so tables whose SELECT policy is owner-only
-- (referrals, saved_posts, saved_profiles, blocked_users, archived_posts)
-- snapshot as EMPTY and every device loses those rows until the next change.
-- That is exactly what happened on 2026-10-09 (sync-rules v3): invite counts
-- dropped to 0 and saved posts vanished, while the server data stayed intact.
--
-- Bypassing RLS is the standard requirement for the PowerSync replication user:
-- what each client actually receives is still limited by the sync rules'
-- bucket parameters (request.user_id()), exactly as for WAL-streamed rows.
--
-- Apply as the DB superuser, then trigger a fresh snapshot (deploy the sync
-- rules with any content change and restart the powersync container):
--   docker exec treepnet-postgres psql -U <super> -d treepnet -f - < powersync-bypassrls.sql

alter role powersync bypassrls;

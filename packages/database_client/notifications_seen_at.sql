-- Notification badge watermark. Idempotent — safe to re-run.
--
-- Notifications are not a table: they are synthesised at read time from likes,
-- comments and subscriptions (see DatabaseClient.notificationsOf), so there is
-- no per-row "read" flag to flip. Instead each profile records when its owner
-- last opened the notifications screen, and anything newer counts as unread.
--
-- Kept on public.profiles rather than device-local storage so the badge clears
-- on every device, the way the chat badge does.
--
-- No GRANT needed: table-level grants on profiles already cover columns added
-- later, and the write goes through the authenticated user's own
-- update-my-profile RLS policy (the same one `bio` uses), not powersync_role.
alter table public.profiles
  add column if not exists notifications_seen_at timestamptz;

-- PostgREST caches the column list. Without a reload the app's UPDATE fails
-- with PGRST204 ("column not found in schema cache"), and because PowerSync
-- uploads strictly in order that one rejection stalls the whole upload queue.
notify pgrst, 'reload schema';

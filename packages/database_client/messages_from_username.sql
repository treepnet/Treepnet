-- The app's local schema and message insert include `from_username`, but the
-- Supabase messages table was created without it — so every outgoing message
-- fails to upload (PGRST204) and blocks the whole PowerSync upload queue.
-- Adding the column aligns Supabase with the client. Idempotent, safe to re-run.
alter table public.messages
  add column if not exists from_username text;

-- Presence (online / last seen). One nullable column on profiles; the app
-- heartbeats it while foregrounded and reads the participant's value in the
-- chat header. profiles already syncs via `select *`, so no sync-rule change.

alter table public.profiles
  add column if not exists last_seen_at timestamptz;

notify pgrst, 'reload schema';

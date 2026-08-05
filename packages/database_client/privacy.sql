-- Adds the private-account flag. Idempotent — safe to re-run.
-- When true, only followers see the profile's posts, stories and travel map.
alter table public.profiles
  add column if not exists is_private boolean not null default false;

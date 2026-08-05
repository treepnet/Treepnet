-- ============================================================================
-- TreepNet — Notifications feed.
--
-- SAFE / idempotent: only adds a `created_at` column to `likes` and
-- `subscriptions` so the in-app Notifications screen can time-order activity
-- (comments already have one). Run in the Supabase SQL editor.
--
-- Existing rows get the alter-time timestamp; new likes/follows are accurate.
-- The columns sync to the client automatically (both tables are in the
-- `global_posts` / `global_subscriptions` PowerSync buckets via `select *`);
-- just make sure the local schema also declares them (schema.dart).
-- ============================================================================

alter table public.likes
  add column if not exists created_at timestamptz not null default now();

alter table public.subscriptions
  add column if not exists created_at timestamptz not null default now();

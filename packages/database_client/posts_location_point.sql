-- ============================================================================
-- TreepNet — exact post location (lat/lng) for per-post map pins.
-- SAFE / idempotent: only adds two nullable columns. Run in Supabase SQL editor.
-- Posts already sync globally in PowerSync (bucket `global_posts` = select *
-- from posts), so no sync-rule change is needed — the new columns sync
-- automatically once added here and declared in the client schema.
-- ============================================================================

alter table public.posts
  add column if not exists location_lat double precision;

alter table public.posts
  add column if not exists location_lng double precision;

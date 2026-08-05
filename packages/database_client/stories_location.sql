-- Adds location columns to `stories` so a story can be pinned to a place.
-- Idempotent — safe to re-run.
--
-- The story content itself expires after 24h (see `expires_at`), but the row is
-- NOT deleted, so its location stays available to the map forever. The app map
-- reads story locations regardless of `expires_at`, which is how a pin remains
-- on the map after the story has disappeared.
alter table public.stories
  add column if not exists location_name text,
  add column if not exists location_lat double precision,
  add column if not exists location_lng double precision;

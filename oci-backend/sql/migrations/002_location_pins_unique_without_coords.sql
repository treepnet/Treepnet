-- A story pinned to a whole region (no coordinates) can be pinned there only
-- once, like a pin at a point.
--
-- The unique (user_id, story_id, region_iso, lat, lng) treated two NULL
-- coordinates as different, so the same region pin could be saved twice.
-- None was on 2026-11-01 (every pin had coordinates), so this applies as is.

alter table public.location_stories drop constraint location_stories_unique;
alter table public.location_stories
  add constraint location_stories_unique
  unique nulls not distinct (user_id, story_id, region_iso, lat, lng);

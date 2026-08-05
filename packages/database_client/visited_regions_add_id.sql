-- PowerSync requires every synced table to expose an `id` column (it becomes
-- the local SQLite row id). The first version used a composite primary key
-- (user_id, region_iso), which made sync-rule validation fail with
-- "Query must return an id column".
--
-- Adds the id, keeps the pair unique so a region can still only be marked once
-- per user. Safe to re-run.

alter table public.visited_regions
  add column if not exists id uuid not null default gen_random_uuid();

alter table public.visited_regions
  drop constraint if exists visited_regions_pkey;

alter table public.visited_regions
  add constraint visited_regions_pkey primary key (id);

alter table public.visited_regions
  drop constraint if exists visited_regions_user_region_key;

alter table public.visited_regions
  add constraint visited_regions_user_region_key unique (user_id, region_iso);

notify pgrst, 'reload schema';

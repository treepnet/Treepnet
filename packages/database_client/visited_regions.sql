-- Places a user marks as "I've been here" during onboarding (and later from
-- the profile). Separate from posts: the travel map should be able to colour a
-- region the user visited even if they never posted from it.
--
-- Run once against the Azure Postgres, then reload PostgREST's schema cache.

create table if not exists public.visited_regions (
  -- PowerSync requires an `id` column on every synced table; the natural key
  -- lives in the unique constraint below.
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  region_iso  text not null,
  created_at  timestamptz not null default now(),
  unique (user_id, region_iso)
);

create index if not exists visited_regions_user_idx
  on public.visited_regions (user_id);

alter table public.visited_regions enable row level security;

-- Visited regions are public (they colour a profile's map, like posts do),
-- but only the owner may add or remove their own.
drop policy if exists visited_regions_select on public.visited_regions;
create policy visited_regions_select on public.visited_regions
  for select using (true);

drop policy if exists visited_regions_insert on public.visited_regions;
create policy visited_regions_insert on public.visited_regions
  for insert with check (auth.uid() = user_id);

drop policy if exists visited_regions_delete on public.visited_regions;
create policy visited_regions_delete on public.visited_regions
  for delete using (auth.uid() = user_id);

grant select on public.visited_regions to anon, authenticated;
grant insert, delete on public.visited_regions to authenticated;


-- PowerSync replicates with its own role; BYPASSRLS lets it ignore policies but
-- does not grant table privileges, so the read has to be granted explicitly.
-- Without this, sync-rule validation fails with "permission denied" and then
-- reports the table as not found.
grant select on public.visited_regions to powersync_role;

-- The `powersync` publication is FOR ALL TABLES, so no ALTER PUBLICATION is
-- needed — but re-checking is harmless if that ever changes.

-- PostgREST caches the schema at boot; without this the new table is invisible
-- and writes are silently rejected.
notify pgrst, 'reload schema';

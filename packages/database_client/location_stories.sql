-- ============================================================================
-- TreepNet — stories pinned to a place on the travel map.
--
-- SAFE to run on the live database: it only ADDS a table, an index and
-- policies. It never drops a table or deletes a row. Re-runnable.
--
-- ⚠ REQUIRED for the Stories tab of a location to work at all. Also add the
--   `global_location_stories` bucket from
--   packages/powersync_repository/sync_rules.txt to the PowerSync sync rules.
--
-- WHY A SEPARATE TABLE
--   A story already carries the location it was posted from, but this is a
--   different thing: the author hand-picks stories out of their archive and
--   pins them to a spot. Nothing lands here automatically, and a story can be
--   pinned to a place it was never shot at.
-- ============================================================================

create table if not exists public.location_stories (
  id          uuid primary key default gen_random_uuid(),
  -- Whose map this pin belongs to. Always the story's author today, but kept
  -- explicit so the queries never have to join `stories` to scope a map.
  user_id     uuid not null references public.profiles (id) on delete cascade,
  story_id    uuid not null references public.stories (id) on delete cascade,
  -- Where it is pinned. `lat`/`lng` are null when pinned to a whole region.
  region_iso  text not null,
  lat         double precision,
  lng         double precision,
  created_at  timestamptz not null default now(),
  -- The same story twice on the same spot is a no-op, not a second card.
  constraint location_stories_unique unique (user_id, story_id, region_iso, lat, lng)
);

create index if not exists location_stories_place_idx
  on public.location_stories (user_id, region_iso);

alter table public.location_stories enable row level security;

-- Readable by everyone: which stories a traveller pinned to a place is public,
-- exactly like their posts. Writable only by the owner of that map.
drop policy if exists "Read location stories" on public.location_stories;
create policy "Read location stories" on public.location_stories
  for select using (true);

drop policy if exists "Pin own location stories" on public.location_stories;
create policy "Pin own location stories" on public.location_stories
  for insert with check (auth.uid() = user_id);

drop policy if exists "Unpin own location stories" on public.location_stories;
create policy "Unpin own location stories" on public.location_stories
  for delete using (auth.uid() = user_id);

grant select on public.location_stories to anon, authenticated;
grant insert, delete on public.location_stories to authenticated;

-- PowerSync replicates with its own role, and BYPASSRLS does not grant
-- privileges. Without this the sync rules fail to validate with
-- "Table public.location_stories not found" — the table is there, the
-- replication role simply cannot see it.
grant select on public.location_stories to powersync_role;

-- PostgREST caches the schema; without this the app's REST calls 404 until the
-- next restart.
notify pgrst, 'reload schema';

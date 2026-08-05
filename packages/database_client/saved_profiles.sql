-- Saved profiles: accounts a user bookmarked from someone else's profile
-- (the "Save" option in the ⋮ menu). Private to the saver — shown under
-- Saved > Profile. Safe to re-run.
--
-- Every synced table needs an `id` (PowerSync) and a SELECT grant to
-- powersync_role, plus a sync-rule bucket (see note at the bottom).

create table if not exists public.saved_profiles (
  id          uuid primary key default gen_random_uuid(),
  saver_id    uuid not null references public.profiles(id) on delete cascade,
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (saver_id, profile_id)
);

create index if not exists saved_profiles_saver_idx
  on public.saved_profiles (saver_id);

alter table public.saved_profiles enable row level security;

-- Only the saver can see or change their saved list.
drop policy if exists saved_profiles_select on public.saved_profiles;
create policy saved_profiles_select on public.saved_profiles
  for select using (auth.uid() = saver_id);

drop policy if exists saved_profiles_write on public.saved_profiles;
create policy saved_profiles_write on public.saved_profiles
  for all using (auth.uid() = saver_id) with check (auth.uid() = saver_id);

grant select on public.saved_profiles to anon, authenticated;
grant insert, update, delete on public.saved_profiles to authenticated;
grant select on public.saved_profiles to powersync_role;

notify pgrst, 'reload schema';

-- PowerSync sync rule — add under bucket_definitions (2-space indent), so the
-- saver syncs their own saved rows:
--
--   saved_profiles:
--     parameters: SELECT request.user_id() as user_id
--     data:
--       - SELECT * FROM saved_profiles WHERE saver_id = bucket.user_id

-- Story views ("seen by") and story likes.
--
-- Both carry an `id` column because PowerSync requires one on every synced
-- table, and both grant SELECT to powersync_role — without it sync-rule
-- validation reports the table as missing. Safe to re-run.

-- Who opened a story. One row per (story, viewer).
create table if not exists public.story_views (
  id          uuid primary key default gen_random_uuid(),
  story_id    uuid not null references public.stories(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (story_id, user_id)
);

create index if not exists story_views_story_idx
  on public.story_views (story_id);

-- Likes on a story. One row per (story, liker); toggled on and off.
create table if not exists public.story_likes (
  id          uuid primary key default gen_random_uuid(),
  story_id    uuid not null references public.stories(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (story_id, user_id)
);

create index if not exists story_likes_story_idx
  on public.story_likes (story_id);
create index if not exists story_likes_user_idx
  on public.story_likes (user_id);

alter table public.story_views enable row level security;
alter table public.story_likes enable row level security;

-- Reads are open (the sync rules decide who actually receives which rows);
-- a person may only record their own view / like.
drop policy if exists story_views_select on public.story_views;
create policy story_views_select on public.story_views for select using (true);

drop policy if exists story_views_insert on public.story_views;
create policy story_views_insert on public.story_views
  for insert with check (auth.uid() = user_id);

drop policy if exists story_likes_select on public.story_likes;
create policy story_likes_select on public.story_likes for select using (true);

drop policy if exists story_likes_insert on public.story_likes;
create policy story_likes_insert on public.story_likes
  for insert with check (auth.uid() = user_id);

drop policy if exists story_likes_delete on public.story_likes;
create policy story_likes_delete on public.story_likes
  for delete using (auth.uid() = user_id);

grant select on public.story_views, public.story_likes to anon, authenticated;
grant insert on public.story_views to authenticated;
grant insert, delete on public.story_likes to authenticated;

-- PowerSync replicates with its own role; BYPASSRLS does not grant privileges.
grant select on public.story_views, public.story_likes to powersync_role;

notify pgrst, 'reload schema';

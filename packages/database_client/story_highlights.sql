-- Story highlights: named, permanent collections of a user's stories shown as
-- circular covers on their profile.
--
-- Every synced table needs an `id` (PowerSync) and a SELECT grant to
-- powersync_role, or sync-rule validation reports the table as missing.
-- Safe to re-run.

create table if not exists public.story_highlights (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  cover_url   text,
  created_at  timestamptz not null default now()
);

create index if not exists story_highlights_user_idx
  on public.story_highlights (user_id);

-- Which stories belong to a highlight. Stories outlive their 24h window (rows
-- are kept), so a highlight keeps working after the story expires.
create table if not exists public.story_highlight_items (
  id            uuid primary key default gen_random_uuid(),
  highlight_id  uuid not null references public.story_highlights(id) on delete cascade,
  story_id      uuid not null references public.stories(id) on delete cascade,
  created_at    timestamptz not null default now(),
  unique (highlight_id, story_id)
);

create index if not exists story_highlight_items_highlight_idx
  on public.story_highlight_items (highlight_id);

alter table public.story_highlights enable row level security;
alter table public.story_highlight_items enable row level security;

-- Highlights are public (they show on a profile); only the owner edits them.
drop policy if exists story_highlights_select on public.story_highlights;
create policy story_highlights_select on public.story_highlights
  for select using (true);

drop policy if exists story_highlights_write on public.story_highlights;
create policy story_highlights_write on public.story_highlights
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists story_highlight_items_select on public.story_highlight_items;
create policy story_highlight_items_select on public.story_highlight_items
  for select using (true);

drop policy if exists story_highlight_items_write on public.story_highlight_items;
create policy story_highlight_items_write on public.story_highlight_items
  for all using (
    exists (
      select 1 from public.story_highlights h
      where h.id = highlight_id and h.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.story_highlights h
      where h.id = highlight_id and h.user_id = auth.uid()
    )
  );

grant select on public.story_highlights, public.story_highlight_items
  to anon, authenticated;
grant insert, update, delete on public.story_highlights, public.story_highlight_items
  to authenticated;
grant select on public.story_highlights, public.story_highlight_items
  to powersync_role;

notify pgrst, 'reload schema';

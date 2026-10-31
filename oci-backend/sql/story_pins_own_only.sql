-- Only your own story can be pinned to your map place or put in your
-- highlight. The rules checked that the place / highlight was yours but not
-- the story, so another person's story could be pinned in through the API.
-- Removing an item stays as it was (the highlight's or place's owner). Prod
-- had no foreign stories in either (2026-10-31). Story views were already
-- limited to the viewer and the story's owner.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < story_pins_own_only.sql
-- Undo: story_pins_own_only_rollback.sql

begin;

drop policy if exists "Pin own location stories" on public.location_stories;
create policy "Pin own location stories" on public.location_stories
  for insert
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.stories s
      where s.id = location_stories.story_id and s.user_id = auth.uid()
    )
  );

-- The one ALL policy becomes three, so adding checks the story too while
-- removing only needs the highlight to be yours.
drop policy if exists story_highlight_items_write on public.story_highlight_items;
drop policy if exists story_highlight_items_insert on public.story_highlight_items;
drop policy if exists story_highlight_items_update on public.story_highlight_items;
drop policy if exists story_highlight_items_delete on public.story_highlight_items;

create policy story_highlight_items_insert on public.story_highlight_items
  for insert
  with check (
    exists (
      select 1 from public.story_highlights h
      where h.id = story_highlight_items.highlight_id and h.user_id = auth.uid()
    )
    and exists (
      select 1 from public.stories s
      where s.id = story_highlight_items.story_id and s.user_id = auth.uid()
    )
  );

create policy story_highlight_items_update on public.story_highlight_items
  for update
  using (
    exists (
      select 1 from public.story_highlights h
      where h.id = story_highlight_items.highlight_id and h.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.story_highlights h
      where h.id = story_highlight_items.highlight_id and h.user_id = auth.uid()
    )
    and exists (
      select 1 from public.stories s
      where s.id = story_highlight_items.story_id and s.user_id = auth.uid()
    )
  );

create policy story_highlight_items_delete on public.story_highlight_items
  for delete
  using (
    exists (
      select 1 from public.story_highlights h
      where h.id = story_highlight_items.highlight_id and h.user_id = auth.uid()
    )
  );

commit;

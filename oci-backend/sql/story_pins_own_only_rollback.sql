-- Undoes story_pins_own_only.sql: the place / highlight has to be yours, the
-- story pinned into it doesn't.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < story_pins_own_only_rollback.sql

begin;

drop policy if exists "Pin own location stories" on public.location_stories;
create policy "Pin own location stories" on public.location_stories
  for insert
  with check (auth.uid() = user_id);

drop policy if exists story_highlight_items_insert on public.story_highlight_items;
drop policy if exists story_highlight_items_update on public.story_highlight_items;
drop policy if exists story_highlight_items_delete on public.story_highlight_items;
create policy story_highlight_items_write on public.story_highlight_items
  for all
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
  );

commit;

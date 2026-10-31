-- Undoes sync_scoping_rls.sql: everything readable by everyone again.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet -v ON_ERROR_STOP=1 < sync_scoping_rls_rollback.sql

begin;

drop policy if exists posts_select on public.posts;
create policy "Allow to see posts for everybody." on public.posts
  for select using (true);

drop policy if exists comments_select on public.comments;
create policy "Everyone can see posts comments." on public.comments
  for select using (true);

drop policy if exists likes_select on public.likes;
create policy "Everyone can see posts likes" on public.likes
  for select using (true);

drop policy if exists stories_select on public.stories;
create policy stories_select on public.stories
  for select using (visibility = 'public' or auth.uid() = user_id);

drop policy if exists story_highlights_select on public.story_highlights;
create policy story_highlights_select on public.story_highlights
  for select using (true);

drop policy if exists story_highlight_items_select on public.story_highlight_items;
create policy story_highlight_items_select on public.story_highlight_items
  for select using (true);

drop policy if exists location_stories_select on public.location_stories;
create policy "Read location stories" on public.location_stories
  for select using (true);

drop policy if exists visited_regions_select on public.visited_regions;
create policy visited_regions_select on public.visited_regions
  for select using (true);

drop policy if exists subscriptions_select on public.subscriptions;
create policy "Every user can see other users subscribers count." on public.subscriptions
  for select using (true);

drop policy if exists story_likes_select on public.story_likes;
create policy story_likes_select on public.story_likes
  for select using (true);

drop policy if exists images_select on public.images;
create policy "Allow to see images for everybody." on public.images
  for select using (true);

drop policy if exists videos_select on public.videos;
create policy "Allow to see videos for everybody" on public.videos
  for select using (true);

commit;

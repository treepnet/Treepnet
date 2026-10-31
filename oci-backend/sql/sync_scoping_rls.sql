-- What phones sync, step 2 of 2 (with the new sync-config.yaml): reading the
-- tables straight through the API follows the same rule as the sync — your
-- own things, and other people's when the account is public or you follow it,
-- and no one's who blocked you or whom you blocked.
--
-- Until now any signed-in user could read every post, like, comment, story
-- pin, highlight, visited region and follow through the API, private
-- accounts' included (`using (true)`). The app reads them through sync and
-- the functions in sync_scoping.sql, which check this themselves; the sync
-- (the powersync role) and the server's own services bypass row security,
-- and the admin panel reads the analytics views, which run as their owner.
--
-- Needs sync_scoping.sql (can_view_author, comments.post_owner_id,
-- story_highlight_items.user_id).
-- Rollback: sync_scoping_rls_rollback.sql.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet -v ON_ERROR_STOP=1 < sync_scoping_rls.sql

begin;

drop policy if exists "Allow to see posts for everybody." on public.posts;
drop policy if exists posts_select on public.posts;
create policy posts_select on public.posts
  for select using (public.can_view_author(user_id));

drop policy if exists "Everyone can see posts comments." on public.comments;
drop policy if exists comments_select on public.comments;
create policy comments_select on public.comments
  for select using (
    auth.uid() = user_id or public.can_view_author(post_owner_id)
  );

-- A like shows where its post (or its comment's post) does.
drop policy if exists "Everyone can see posts likes" on public.likes;
drop policy if exists likes_select on public.likes;
create policy likes_select on public.likes
  for select using (
    auth.uid() = user_id
    or exists (select 1 from public.posts p
                where p.id = likes.post_id
                  and public.can_view_author(p.user_id))
    or exists (select 1 from public.comments c
                where c.id = likes.comment_id
                  and public.can_view_author(c.post_owner_id))
  );

drop policy if exists stories_select on public.stories;
create policy stories_select on public.stories
  for select using (
    auth.uid() = user_id
    or (visibility = 'public' and public.can_view_author(user_id))
  );

drop policy if exists story_highlights_select on public.story_highlights;
create policy story_highlights_select on public.story_highlights
  for select using (public.can_view_author(user_id));

drop policy if exists story_highlight_items_select on public.story_highlight_items;
create policy story_highlight_items_select on public.story_highlight_items
  for select using (public.can_view_author(user_id));

drop policy if exists "Read location stories" on public.location_stories;
drop policy if exists location_stories_select on public.location_stories;
create policy location_stories_select on public.location_stories
  for select using (public.can_view_author(user_id));

drop policy if exists visited_regions_select on public.visited_regions;
create policy visited_regions_select on public.visited_regions
  for select using (public.can_view_author(user_id));

-- Your own follows both ways; someone else's when both people show to you.
drop policy if exists "Every user can see other users subscribers count." on public.subscriptions;
drop policy if exists subscriptions_select on public.subscriptions;
create policy subscriptions_select on public.subscriptions
  for select using (
    auth.uid() = subscriber_id
    or auth.uid() = subscribed_to_id
    or (status = 'accepted'
        and public.can_view_author(subscribed_to_id)
        and public.can_view_author(subscriber_id))
  );

-- No longer in the app or the sync: only their owner reads them.
drop policy if exists story_likes_select on public.story_likes;
create policy story_likes_select on public.story_likes
  for select using (auth.uid() = user_id);
drop policy if exists "Allow to see images for everybody." on public.images;
drop policy if exists images_select on public.images;
create policy images_select on public.images
  for select using (auth.uid() = owner_id);
drop policy if exists "Allow to see videos for everybody" on public.videos;
drop policy if exists videos_select on public.videos;
create policy videos_select on public.videos
  for select using (auth.uid() = owner_id);

commit;

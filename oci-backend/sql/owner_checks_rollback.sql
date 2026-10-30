-- Undoes owner_checks.sql: inserts are open to any signed-in caller again, the
-- follower sets the follow status, the phone sets story times, and story views
-- are readable by everyone. Only for an emergency.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < owner_checks_rollback.sql

begin;

drop trigger if exists stories_server_times on public.stories;
drop function if exists public.stories_server_times();

drop trigger if exists subscriptions_enforce on public.subscriptions;
drop function if exists public.subscriptions_enforce();

alter policy story_views_select on public.story_views using (true);

-- The update policy had no WITH CHECK before (its USING applied); recreate it
-- exactly as it was.
drop policy "Only owners can update stories." on public.stories;
create policy "Only owners can update stories." on public.stories
  for update to authenticated using (auth.uid() = user_id);

alter policy "Only authenticated users can subscribe to other users." on public.subscriptions
  with check (true);
alter policy "Allow to create profiles for everyone." on public.profiles
  with check (true);
alter policy "Only authenticated users can add stories." on public.stories
  with check (true);
alter policy "Only authenticated can upload likes" on public.likes
  with check (true);
alter policy "Only authenticated can upload comments." on public.comments
  with check (true);
alter policy "Allow upload post only to authenticated user." on public.posts
  with check (true);

commit;

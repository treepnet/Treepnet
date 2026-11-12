-- A replaced or removed avatar's file is deleted.
--
-- delete_old_avatar() (trigger before_profile_changes) has done nothing since
-- Supabase Storage went. Every new avatar is a new file (named by its upload
-- time), so each change left the previous photo in the bucket, readable by
-- anyone who had its link. Now the old file goes the way a deleted post's or
-- story's does: queue_media_deletion() skips it while anything still uses it
-- (another avatar, a post, a story, a highlight cover), and the clean-up
-- worker (functions/delete-account/cleanup.js) checks again before deleting.
--
-- The trigger runs after media_refs_sync on the same row (AFTER triggers fire
-- in name order), so media_in_use() already sees the new avatar in place of
-- the old one. Account deletion is unchanged: delete_account_by_id queues the
-- current avatar, and the worker clears the account's avatar folder.

create or replace function public.queue_old_avatar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.avatar_url is not null and old.avatar_url is distinct from new.avatar_url then
    perform queue_media_deletion(array[old.avatar_url]);
  end if;
  return null;
end;
$$;
revoke all on function public.queue_old_avatar() from public, anon, authenticated;

drop trigger if exists on_avatar_replaced on public.profiles;
create trigger on_avatar_replaced after update of avatar_url on public.profiles
  for each row execute function public.queue_old_avatar();

-- The no-op it replaces.
drop trigger if exists before_profile_changes on public.profiles;
drop function if exists public.delete_old_avatar();

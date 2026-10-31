-- A post's owner may delete any comment on it. The app offers them that
-- (user_comment.dart: post author or comment author), but the server only let
-- a comment's author delete it: the delete matched no row and returned no
-- error, so the comment vanished on the phone and came back with the next
-- sync. Authors deleting their own comments is unchanged; replies and likes
-- on a deleted comment still go with it (ON DELETE CASCADE).
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < comments_post_owner_delete.sql
-- Undo: comments_post_owner_delete_rollback.sql

begin;

drop policy if exists "Post owners can delete comments on their posts."
  on public.comments;
create policy "Post owners can delete comments on their posts."
  on public.comments
  for delete
  to authenticated
  using (
    exists (
      select 1 from public.posts p
      where p.id = comments.post_id and p.user_id = auth.uid()
    )
  );

commit;

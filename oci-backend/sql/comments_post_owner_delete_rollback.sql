-- Undoes comments_post_owner_delete.sql: only a comment's author may delete it.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < comments_post_owner_delete_rollback.sql

begin;
drop policy if exists "Post owners can delete comments on their posts."
  on public.comments;
commit;

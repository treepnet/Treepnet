-- Delete a post's or a story's photo from object storage when its owner
-- deletes the post or story.
--
-- Deleting a post or a story removed only its row: the file stayed in the
-- bucket, readable by anyone who had its link (shared, cached), and storage
-- kept growing. (Whole accounts were already handled: delete_account_by_id
-- queues their files in account_deletion_jobs.)
--
-- The delete triggers (once Supabase no-ops) now put the file's URL in
-- media_deletion_queue, unless the file is still used somewhere — another
-- post, a story, a highlight cover, an avatar. The delete-account service's
-- worker (functions/delete-account/cleanup.js) checks that again, deletes the
-- object and drops the row; failures are retried and reported.
--
-- A highlight whose cover was the deleted story's picture takes the picture of
-- its first remaining story (or none, when it has no stories left).
--
-- Expired stories are NOT deleted: highlights, place pins and the archive
-- still show them.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet \
--     -v ON_ERROR_STOP=1 < media_deletion_queue.sql
-- Undo: the trigger functions back to `begin return old; end`, then
--   drop table public.media_deletion_queue; drop function
--   public.queue_media_deletion(text[]), public.media_in_use(text),
--   public.media_object_key(text);

begin;

create table if not exists public.media_deletion_queue (
  url             text primary key,
  queued_at       timestamptz not null default now(),
  attempts        int not null default 0,
  last_error      text,
  next_attempt_at timestamptz not null default now()
);
revoke all on public.media_deletion_queue from public, anon, authenticated;

-- The object a media URL points at (bucket or media.treepnet.com form, no
-- query string): what two links to the same file have in common.
create or replace function public.media_object_key(p_url text)
returns text
language sql
immutable
as $$
  select nullif(coalesce(
    substring(p_url from '/b/treepnet-media/o/([^?#]+)'),
    substring(p_url from '^https://media\.treepnet\.com/([^?#]+)')
  ), '')
$$;

-- Whether the file behind [p_url] is still used by a post, a story, a
-- highlight cover or an avatar.
create or replace function public.media_in_use(p_url text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select media_object_key(p_url) is not null and (
       exists (select 1 from posts where strpos(media, media_object_key(p_url)) > 0)
    or exists (select 1 from stories where strpos(content_url, media_object_key(p_url)) > 0)
    or exists (select 1 from story_highlights where strpos(cover_url, media_object_key(p_url)) > 0)
    or exists (select 1 from profiles where strpos(avatar_url, media_object_key(p_url)) > 0)
  )
$$;

create or replace function public.queue_media_deletion(p_urls text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
begin
  foreach v_url in array coalesce(p_urls, '{}') loop
    continue when media_object_key(v_url) is null or media_in_use(v_url);
    insert into media_deletion_queue (url) values (v_url)
      on conflict (url) do nothing;
  end loop;
end;
$$;

create or replace function public.handle_delete_post_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- The same URLs delete_account_by_id collects: the post's media is a JSON
  -- string, matched as text.
  perform queue_media_deletion(array(
    select (regexp_matches(
      coalesce(old.media, ''),
      'https://(?:objectstorage\.[^"]*/b/treepnet-media/o/|media\.treepnet\.com/)[^"]*',
      'g'))[1]
  ));
  return old;
end;
$$;

create or replace function public.handle_delete_story_media()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Its highlight items are already gone (they cascade first), so this picks
  -- among the stories left in each highlight.
  update story_highlights h
     set cover_url = (
       select s.content_url
         from story_highlight_items i
         join stories s on s.id = i.story_id
        where i.highlight_id = h.id
        order by i.created_at, s.created_at
        limit 1)
   where h.cover_url = old.content_url;
  perform queue_media_deletion(array[old.content_url]);
  return old;
end;
$$;

revoke all on function public.media_object_key(text) from public, anon, authenticated;
revoke all on function public.media_in_use(text) from public, anon, authenticated;
revoke all on function public.queue_media_deletion(text[]) from public, anon, authenticated;
revoke all on function public.handle_delete_post_media() from public, anon, authenticated;
revoke all on function public.handle_delete_story_media() from public, anon, authenticated;

commit;

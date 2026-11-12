-- Whether a photo file is still used is one index lookup, not a scan.
--
-- media_in_use() searched the text of every post, story, highlight cover and
-- avatar for the file's key (strpos, which no index can serve). It runs for
-- every photo of a deleted post or story, again when the clean-up worker
-- takes it, and for every photo of a deleted account, inside an API call cut
-- at 5 s. Now each row's file keys are kept in media_refs, by triggers on the
-- four tables, and media_in_use() looks the key up there.
--
-- It also decides whether a file is deleted for good (the account-deletion
-- fix of 2026-11-11 relies on it), so: the keys are found the way the
-- deletions find them (the same URL pattern for posts, the same columns), the
-- triggers run before the deletion triggers of the same row (triggers fire in
-- name order: media_refs_sync before on_post_deleted / on_story_deleted), and
-- media_refs_check() (daily, crontab.txt) fails loudly if media_refs ever
-- differs from the tables.

create table if not exists public.media_refs (
  key text not null,
  source text not null,      -- post | story | highlight | avatar
  source_id uuid not null,
  primary key (source, source_id, key)
);
create index if not exists media_refs_by_key on public.media_refs (key);
revoke all on table public.media_refs from public, anon, authenticated;

-- The file keys a row of [p_source] (as JSON) points at.
create or replace function public.media_keys(p_source text, p_row jsonb)
returns setof text
language sql
stable
set search_path = public
as $$
  select distinct media_object_key(u)
    from (
      -- A post's media is a JSON string; its URLs are matched as text, as
      -- handle_delete_post_media and delete_account_by_id collect them.
      select (regexp_matches(coalesce(p_row ->> 'media', ''),
               'https://(?:objectstorage\.[^"]*/b/treepnet-media/o/|media\.treepnet\.com/)[^"]*',
               'g'))[1] as u
       where p_source = 'post'
      union all select p_row ->> 'content_url' where p_source = 'story'
      union all select p_row ->> 'cover_url' where p_source = 'highlight'
      union all select p_row ->> 'avatar_url' where p_source = 'avatar'
    ) urls
   where media_object_key(u) is not null
$$;
revoke all on function public.media_keys(text, jsonb) from public, anon, authenticated;

create or replace function public.media_refs_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source text := tg_argv[0];
begin
  if tg_op in ('UPDATE', 'DELETE') then
    delete from media_refs where source = v_source and source_id = old.id;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    insert into media_refs (key, source, source_id)
    select k, v_source, new.id from media_keys(v_source, to_jsonb(new)) k
    on conflict do nothing;
  end if;
  return null;
end;
$$;
revoke all on function public.media_refs_sync() from public, anon, authenticated;

drop trigger if exists media_refs_sync on public.posts;
create trigger media_refs_sync after insert or delete or update of media on public.posts
  for each row execute function public.media_refs_sync('post');
drop trigger if exists media_refs_sync on public.stories;
create trigger media_refs_sync after insert or delete or update of content_url on public.stories
  for each row execute function public.media_refs_sync('story');
drop trigger if exists media_refs_sync on public.story_highlights;
create trigger media_refs_sync after insert or delete or update of cover_url on public.story_highlights
  for each row execute function public.media_refs_sync('highlight');
drop trigger if exists media_refs_sync on public.profiles;
create trigger media_refs_sync after insert or delete or update of avatar_url on public.profiles
  for each row execute function public.media_refs_sync('avatar');

-- What media_refs should hold, from the tables themselves.
create or replace function public.media_refs_expected()
returns table(key text, source text, source_id uuid)
language sql
stable
set search_path = public
as $$
  select k, 'post', p.id from posts p, media_keys('post', to_jsonb(p)) k
  union all select k, 'story', s.id from stories s, media_keys('story', to_jsonb(s)) k
  union all select k, 'highlight', h.id from story_highlights h, media_keys('highlight', to_jsonb(h)) k
  union all select k, 'avatar', a.id from profiles a, media_keys('avatar', to_jsonb(a)) k
$$;
revoke all on function public.media_refs_expected() from public, anon, authenticated;

insert into media_refs (key, source, source_id)
select * from media_refs_expected()
on conflict do nothing;

-- Raises when media_refs differs from the tables (a write path the triggers
-- miss would make media_in_use() wrong, and files could be deleted while in
-- use). Daily from cron; its error goes to cron-errors.log, which the server
-- monitor reports.
create or replace function public.media_refs_check()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_diff integer;
begin
  select count(*) into v_diff from (
    (select * from media_refs_expected()
     except select key, source, source_id from media_refs)
    union all
    (select key, source, source_id from media_refs
     except select * from media_refs_expected())
  ) d;
  if v_diff > 0 then
    raise exception 'media_refs differs from the tables in % rows', v_diff;
  end if;
  return 0;
end;
$$;
revoke all on function public.media_refs_check() from public, anon, authenticated;

create or replace function public.media_in_use(p_url text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select media_object_key(p_url) is not null
     and exists (select 1 from media_refs where key = media_object_key(p_url))
$$;

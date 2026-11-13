-- A highlight's cover follows what is in it.
--
-- Taking a story out of a highlight removed only the link: the cover stayed
-- that story's picture, so the highlight showed a story no longer in it (in
-- the pin sheet even once empty, and still after a new story went in). The
-- cover was re-picked only when the story itself was deleted
-- (handle_delete_story_media).
--
-- Now a story taken out that was the cover hands it to the first story left
-- (the owner's own; none left: no cover), and a story put into a highlight
-- with no cover becomes it. Takes effect for every build; no app change.

create or replace function public.story_highlight_cover_follows_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text;
begin
  if tg_op = 'DELETE' then
    -- Gone with its story (that delete re-picks the cover itself): nothing
    -- to compare with here.
    select s.content_url into v_url from stories s where s.id = old.story_id;
    if v_url is null then
      return null;
    end if;
    update story_highlights h
       set cover_url = (
         select s.content_url
           from story_highlight_items i
           join stories s on s.id = i.story_id
          where i.highlight_id = h.id
            and s.user_id = h.user_id
          order by i.created_at, s.created_at
          limit 1)
     where h.id = old.highlight_id
       and h.cover_url = v_url;
  else
    update story_highlights h
       set cover_url = s.content_url
      from stories s
     where h.id = new.highlight_id
       and s.id = new.story_id
       and s.user_id = h.user_id
       and coalesce(h.cover_url, '') = '';
  end if;
  return null;
end;
$$;

revoke all on function public.story_highlight_cover_follows_items() from public, anon, authenticated;

drop trigger if exists story_highlight_items_cover on public.story_highlight_items;
create trigger story_highlight_items_cover
  after insert or delete on public.story_highlight_items
  for each row
  execute function public.story_highlight_cover_follows_items();

-- Covers already left behind by a story taken out.
update public.story_highlights h
   set cover_url = (
     select s.content_url
       from public.story_highlight_items i
       join public.stories s on s.id = i.story_id
      where i.highlight_id = h.id
        and s.user_id = h.user_id
      order by i.created_at, s.created_at
      limit 1)
 where coalesce(h.cover_url, '') <> ''
   and not exists (
     select 1
       from public.story_highlight_items i
       join public.stories s on s.id = i.story_id
      where i.highlight_id = h.id
        and s.content_url = h.cover_url);

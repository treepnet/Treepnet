-- A post's media and caption must be readable.
--
-- Nothing checked them: the policies only ask that the post is the user's
-- own, and both columns took NULL or any text. The app reads a list of posts
-- all or nothing, so one unreadable post (an old buggy build, or on purpose)
-- broke the home feed of everyone following its author, and Newest and
-- Trends for everyone. Production data was clean when this was added.
--
-- media: a JSON array of 1 to 10 objects, each with a string type and a
-- string url (empty while the photo is still uploading).
-- caption: never NULL; an empty caption is ''.

create or replace function public.post_media_ok(p_media text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v jsonb;
  e jsonb;
begin
  if p_media is null then
    return false;
  end if;
  begin
    v := p_media::jsonb;
  exception when others then
    return false;
  end;
  if jsonb_typeof(v) <> 'array' or jsonb_array_length(v) not between 1 and 10 then
    return false;
  end if;
  for e in select value from jsonb_array_elements(v) loop
    if jsonb_typeof(e) <> 'object'
       or jsonb_typeof(e -> 'type') is distinct from 'string'
       or jsonb_typeof(e -> 'url') is distinct from 'string' then
      return false;
    end if;
  end loop;
  return true;
end;
$$;

-- A CHECK runs with the rights of whoever writes the row, and new functions
-- aren't executable by default: the app's role needs it.
revoke all on function public.post_media_ok(text) from public, anon;
grant execute on function public.post_media_ok(text) to authenticated;

alter table public.posts
  add constraint posts_media_well_formed check (public.post_media_ok(media));

alter table public.posts alter column caption set default '';
alter table public.posts alter column caption set not null;

-- A story view the server won't keep is dropped quietly instead of failing.
--
-- A view is written in the background as a story is watched. One that
-- reached the server after the story was deleted (watched offline, or seconds
-- before its owner deleted it) found no owner: the NOT NULL owner column, then
-- the story's foreign key, refused it. The app treats a refused row as final:
-- the viewer saw "Change not saved" for nothing they did, and a crash report
-- went out.
--
-- Two more were kept that shouldn't be: an owner's view of their own story
-- (old builds wrote them; 9 rows on prod, in the owners' "seen by" counts),
-- and a view from someone who may not see the owner's stories (blocked either
-- way, or a private account they don't follow), counted in the owner's total
-- though the list of viewers hides blocked people.
--
-- As with repeats (003, 013), only the caller's own rows are skipped.
-- Takes effect for every build; no app change.

create or replace function public.story_views_set_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select s.user_id into new.story_owner_id
    from public.stories s
   where s.id = new.story_id;
  if tg_op = 'INSERT' and new.user_id = auth.uid() and (
       new.story_owner_id is null
       or new.story_owner_id = new.user_id
       or not public.can_view_author(new.story_owner_id)) then
    return null;
  end if;
  return new;
end;
$$;

-- Owners' views of their own stories, from old builds.
delete from public.story_views where user_id = story_owner_id;

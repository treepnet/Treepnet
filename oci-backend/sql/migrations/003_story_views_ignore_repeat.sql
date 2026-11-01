-- Seeing a story again is not an error: the second view of the same story by
-- the same person is dropped quietly instead of failing.
--
-- A viewer's own view rows don't sync back to them (only the story's owner
-- gets them), so the app can't tell it already sent one, and a second
-- viewing sent a new row. The unique (story_id, user_id) refused it — an
-- error the app treats as final: it showed "Change not saved" and filed a
-- crash report for watching a story twice. Older builds benefit at once.

create or replace function public.story_views_ignore_repeat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (select 1 from story_views v
              where v.story_id = new.story_id and v.user_id = new.user_id) then
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.story_views_ignore_repeat() from public, anon, authenticated;

drop trigger if exists story_views_ignore_repeat on public.story_views;
create trigger story_views_ignore_repeat
  before insert on public.story_views
  for each row execute function public.story_views_ignore_repeat();

-- Legacy objects nothing uses go, and auth.uid() reads Firebase's claim only.
--
-- Left from the Supabase / Entra days, they misled (the TRUNCATE triggers and
-- the storage functions looked like media clean-up) and widened the room for
-- mistakes; four were SECURITY DEFINER, three without a fixed search_path.
-- Checked on production first (2026-11-16): the tables are empty (auth.users
-- held 2 orphan emails), no code, view, trigger or sync rule uses any of it.
--   * images, videos (closed to the API in 004), story_likes (story likes went
--     with #126); account deletion stops clearing them.
--   * auth.users, the old Supabase sign-in table.
--   * delete_storage_object / delete_avatar (they called a missing
--     extensions.http), delete_old_profile, handle_new_user and
--     handle_update_user (no trigger used them).
--   * clear_posts_trigger / clear_stories_trigger and their functions: TRUNCATE
--     triggers that did nothing.
--   * The empty schemas storage and extensions.
-- Not undoable but from a backup.

-- Account deletion without the dropped tables: those lines are taken out of
-- the function as it is now; it stops if they are no longer what it expects.
do $migration$
declare
  v_def text := pg_get_functiondef('public.delete_account_by_id(uuid)'::regprocedure);
  v_new text := v_def;
  v_line text;
begin
  foreach v_line in array array[
    E'      union all select url from images where owner_id = p_uid\n',
    E'      union all select url from videos where owner_id = p_uid\n',
    E'      union all select first_frame_url from videos where owner_id = p_uid\n',
    E'  delete from story_likes           where user_id = p_uid;\n',
    E'  delete from images                where owner_id = p_uid;\n',
    E'  delete from videos                where owner_id = p_uid;\n'
  ] loop
    if position(v_line in v_new) = 0 then
      raise exception 'delete_account_by_id no longer has the line %: update the file', v_line;
    end if;
    v_new := replace(v_new, v_line, '');
  end loop;
  if v_new ~ '\m(images|videos|story_likes)\M' then
    raise exception 'delete_account_by_id still names a dropped table: update the file';
  end if;
  execute v_new;
end
$migration$;

drop trigger clear_posts_trigger on public.posts;
drop trigger clear_stories_trigger on public.stories;
drop function public.clear_posts_objects();
drop function public.clear_stories_objects();
drop function public.delete_avatar(text);
drop function public.delete_storage_object(text, text);
drop function public.delete_old_profile();
drop function public.handle_new_user();
drop function public.handle_update_user();

drop table public.story_likes;
drop table public.images;
drop table public.videos;
drop table auth.users;

drop schema storage;
drop schema extensions;

-- The signed-in user is the token's 'sub' (Firebase: the profile id). It
-- preferred Entra's 'oid' first, a claim no token carries any more.
create or replace function auth.uid()
 returns uuid
 language sql
 stable
as $function$
  select v::uuid from (
    select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub' as v
  ) t
  -- Not shaped like a UUID: null instead of an error.
  where v ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
$function$;

-- The API answers only signed-in users, but for the one question the sign-up
-- screen asks before there is an account: is this username taken?
--
-- PostgREST runs a request without a token as `authenticated`
-- (PGRST_DB_ANON_ROLE, which must stay so while Firebase tokens carry no
-- role claim: docker-compose.yml). So without an account anyone could read
-- every profile's name, bio and links, the follow graph and public posts with
-- their coordinates, and call every RPC (feed_posts, search_profiles,
-- follow_list...), 500 rows a request, with no user to tie it to.
--
-- PostgREST calls this before every request (PGRST_DB_PRE_REQUEST). A signed-
-- in request (a token whose sub is a user id) goes on as before. Without one:
-- GET /profiles runs as `anon`, which may read only id and username (the
-- sign-up check, GET /profiles?select=id&username=eq.<name>, and the uptime
-- checks); anything else is refused with 401.

create or replace function public.api_require_sign_in()
returns void
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null then
    return;
  end if;
  if current_setting('request.method', true) = 'GET'
     and current_setting('request.path', true) = '/profiles' then
    set local role anon;
    return;
  end if;
  raise sqlstate 'PT401' using message = 'Sign in required';
end;
$$;

revoke all on function public.api_require_sign_in() from public, anon;
grant execute on function public.api_require_sign_in() to authenticated;

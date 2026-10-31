-- A request without a token used to run as `authenticated` (the same role
-- as a signed-in user, with auth.uid() null): anyone could read every post,
-- comment, like and follow through the public API. It now runs as `anon`,
-- which can only see a profile's id and username — all the app needs before
-- sign-in (the "is this username taken?" check during sign-up).
--
-- Also: every API query (either role) is stopped after 5 seconds, so one
-- request can't hold the single database. PostgREST applies the impersonated
-- role's settings per request.
--
-- Goes with docker-compose.yml: PGRST_DB_ANON_ROLE=anon,
-- PGRST_OPENAPI_MODE=disabled, PGRST_DB_MAX_ROWS=500.
-- Undo: postgrest_anon_role_rollback.sql (and the compose values back).
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < postgrest_anon_role.sql

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
end
$$;

-- PostgREST logs in as authenticator and switches to anon per request.
grant anon to authenticator;

grant usage on schema public to anon;
grant select (id, username) on public.profiles to anon;

alter role anon set statement_timeout = '5s';
alter role authenticated set statement_timeout = '5s';

commit;

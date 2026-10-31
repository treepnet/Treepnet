-- Undoes postgrest_anon_role.sql. Put PGRST_DB_ANON_ROLE back to
-- `authenticated` in docker-compose.yml FIRST (and recreate postgrest), or
-- requests without a token fail while the role is gone.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < postgrest_anon_role_rollback.sql

begin;

alter role authenticated reset statement_timeout;

revoke select (id, username) on public.profiles from anon;
revoke usage on schema public from anon;
revoke anon from authenticator;
drop role if exists anon;

commit;

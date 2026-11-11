-- The roles the schema grants to, for a new server, before sql/migrate.sh.
--   authenticator  : the LOGIN role PostgREST connects as; it SET ROLEs to authenticated.
--   authenticated  : every API request runs as this role, a request without a
--                    token too (PGRST_DB_ANON_ROLE). Row security is enforced by
--                    the RLS policies via auth.uid().
--   anon           : granted a few public columns (profiles id, username).
--   analytics_ro   : analytics-api (SELECT on the analytics.* views).
--   chat_blocks_ro : the chat server's block check (sql/chat_blocks_ro.sql).
-- (powersync comes from postgres/initdb/01-powersync.sh.)
--
-- Only the roles: every privilege, default privileges included, comes from
-- the migrations (000_baseline.sql records them as production had them). This
-- file used to GRANT ALL on every table and EXECUTE on every function, which
-- on a rebuild opened the locked internal functions (account deletion, the
-- push queue) to anyone.
--
-- Passwords are psql variables, never inline: :pw for authenticator. Set the
-- analytics_ro and chat_blocks_ro passwords from the server .env
-- (ANALYTICS_RO_PASS, CHAT_BLOCKS_RO_PASS) with ALTER ROLE ... PASSWORD.

DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator LOGIN NOINHERIT;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'analytics_ro') THEN
    CREATE ROLE analytics_ro LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'chat_blocks_ro') THEN
    CREATE ROLE chat_blocks_ro LOGIN;
  END IF;
END $$;

ALTER ROLE authenticator WITH PASSWORD :'pw';
GRANT authenticated TO authenticator;
GRANT anon TO authenticator;

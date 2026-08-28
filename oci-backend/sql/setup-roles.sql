-- PostgREST role model (matches Azure: PGRST_DB_ANON_ROLE = authenticated).
--   authenticator : the LOGIN role PostgREST connects as; it SET ROLEs to authenticated.
--   authenticated : every request runs as this role. Row security is enforced by
--                   the restored RLS policies via auth.uid() (the Entra `oid`).
-- Password for authenticator is passed as psql var :pw (never inline).

DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE ROLE authenticator LOGIN NOINHERIT;
  END IF;
END $$;

ALTER ROLE authenticator WITH PASSWORD :'pw';
GRANT authenticated TO authenticator;

-- Broad table privileges; RLS restricts the actual rows per user.
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA auth, extensions, storage TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;

-- New tables and sequences in public are closed by default.
--
-- A default privilege granted every right on each new table to
-- authenticated, which PostgREST also uses for requests without a token, and
-- new tables have no RLS: each internal table (push_outbox,
-- media_deletion_queue, schema_migrations, account_deletion_jobs, mail_sends)
-- had to be revoked by hand, and one forgotten would be open to anyone. The
-- pg_stat_statements objects added on 2026-10-31 were opened that way too.
--
-- Existing grants don't change. From here on a migration that adds a table
-- the app reads or writes grants it explicitly (and turns on RLS).

alter default privileges for role treepnet in schema public
  revoke all on tables from authenticated;
alter default privileges for role treepnet in schema public
  revoke all on sequences from authenticated;

do $$
declare
  r record;
begin
  for r in
    select c.oid::regclass as name
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relname like 'pg_stat_statements%'
  loop
    execute format('revoke all on %s from public, anon, authenticated', r.name);
  end loop;
end $$;

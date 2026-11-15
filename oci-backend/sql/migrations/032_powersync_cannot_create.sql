-- The sync service's login can no longer create objects.
--
-- powersync (the login of the internet-facing PowerSync service) held CREATE
-- on the database and on schema public, which it never used: it owns no
-- object here (checked 2026-11-16). With its password, anyone could have
-- added functions or tables to the schema the API serves. It keeps CONNECT,
-- TEMP, USAGE, replication and BYPASSRLS (the sync rules need that).
--
-- Its read access to the private tables (password hashes, codes, the push
-- queue) stays for now: the publication is FOR ALL TABLES, so that goes
-- together with narrowing the publication at the next planned re-sync.

do $migration$
begin
  execute format('revoke create on database %I from powersync', current_database());
end
$migration$;
revoke create on schema public from powersync;

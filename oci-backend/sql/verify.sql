SHOW wal_level;
SELECT rolname, rolreplication FROM pg_roles WHERE rolname = 'powersync';
SELECT pubname, puballtables FROM pg_publication;

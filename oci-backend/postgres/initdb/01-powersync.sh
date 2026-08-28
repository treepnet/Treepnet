#!/bin/bash
# Runs once, on first Postgres cluster init (docker-entrypoint-initdb.d).
# Creates the PowerSync logical-replication role and the publication it reads.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE "$POWERSYNC_PG_USER" WITH REPLICATION LOGIN PASSWORD '$POWERSYNC_PG_PASSWORD';
  GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_DB" TO "$POWERSYNC_PG_USER";
  GRANT ALL ON SCHEMA public TO "$POWERSYNC_PG_USER";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "$POWERSYNC_PG_USER";
  -- PowerSync replicates from this publication (covers current + future tables).
  CREATE PUBLICATION powersync FOR ALL TABLES;
EOSQL

echo "PowerSync role + publication created."

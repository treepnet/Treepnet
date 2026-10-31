-- PowerSync reads changes through a logical replication slot, and Postgres
-- keeps every WAL file a slot still needs. With no limit (the default), a
-- PowerSync that stops or falls behind makes Postgres keep WAL until the disk
-- is full — and then every service on the server stops.
--
-- Past 4GB the slot is given up instead ("lost"): the database keeps running
-- and PowerSync replicates everything again from scratch (the powersync role
-- has BYPASSRLS for that, see powersync-bypassrls.sql). treepnet-monitor.sh
-- alerts as soon as a slot nears or passes the limit.
--
-- Takes effect on reload, no restart. Stored in postgresql.auto.conf in the
-- data volume (deliberately not a -c flag in docker-compose.yml: changing the
-- postgres command makes the next `docker compose up` restart the database).
-- ALTER SYSTEM can't run inside a transaction, hence no begin/commit.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < wal_slot_limit.sql
-- Undo: wal_slot_limit_rollback.sql

alter system set max_slot_wal_keep_size = '4GB';
select pg_reload_conf();

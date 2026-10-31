-- Undoes wal_slot_limit.sql: replication slots keep WAL without limit again.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < wal_slot_limit_rollback.sql

alter system reset max_slot_wal_keep_size;
select pg_reload_conf();

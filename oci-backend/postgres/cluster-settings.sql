-- Server-level Postgres settings production runs with.
--
-- They live in postgresql.auto.conf inside the data volume (set with ALTER
-- SYSTEM, see sql/postgres_tuning.sql and sql/wal_slot_limit.sql for why each
-- one), so neither pg_dump, the nightly backup nor migrate.sh carries them: a
-- rebuilt server would start on stock settings (128 MB cache, no limit on the
-- WAL a stalled PowerSync makes Postgres keep, no slow-query log). Keep this
-- file in step with the server when a setting changes.
--
-- ALTER SYSTEM can't run in a transaction. Apply, check, then restart (the
-- first two settings need one):
--   docker exec -i treepnet-postgres psql -U <super> -d postgres -v ON_ERROR_STOP=1 < cluster-settings.sql
--   docker exec -u postgres treepnet-postgres postgres -D /var/lib/postgresql/data -C shared_buffers
--   docker restart treepnet-postgres
-- then in the treepnet database: create extension if not exists pg_stat_statements;

alter system set shared_buffers = '2GB';
alter system set shared_preload_libraries = 'pg_stat_statements';

alter system set effective_cache_size = '6GB';
alter system set work_mem = '16MB';
alter system set maintenance_work_mem = '256MB';
alter system set random_page_cost = 1.1;
alter system set effective_io_concurrency = 200;
alter system set track_io_timing = on;
alter system set log_min_duration_statement = '1s';
alter system set log_parameter_max_length = 0;
alter system set max_slot_wal_keep_size = '4GB';

select pg_reload_conf();

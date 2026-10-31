-- Undoes postgres_tuning.sql (then `docker restart treepnet-postgres` for
-- shared_buffers / shared_preload_libraries). Drop the extension first, or it
-- stays installed without its library loaded:
--   drop extension if exists pg_stat_statements;
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < postgres_tuning_rollback.sql
--
-- If Postgres won't start after a bad setting, remove the line from
-- postgresql.auto.conf in the volume without starting it:
--   docker run --rm -v treepnet_pgdata:/d alpine sed -i '/^shared_buffers/d' /d/postgresql.auto.conf

alter system reset shared_buffers;
alter system reset effective_cache_size;
alter system reset work_mem;
alter system reset maintenance_work_mem;
alter system reset random_page_cost;
alter system reset effective_io_concurrency;
alter system reset shared_preload_libraries;
alter system reset track_io_timing;
alter system reset log_min_duration_statement;
alter system reset log_parameter_max_length;

select pg_reload_conf();

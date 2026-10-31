-- Postgres ran on stock settings on an 11GB server: a 128MB cache, 4MB per
-- sort, costs tuned for spinning disks, and no record of which queries are
-- slow. Sized here for the 11GB OCI VM it shares with PowerSync, the Node
-- services and Caddy.
--
-- Stored in postgresql.auto.conf in the data volume (deliberately not -c
-- flags in docker-compose.yml: changing the postgres command makes the next
-- `docker compose up` restart the database). ALTER SYSTEM can't run inside a
-- transaction, hence no begin/commit.
--
-- shared_buffers and shared_preload_libraries need a restart; check the
-- result first (a bad value keeps Postgres from starting):
--   docker exec -u postgres treepnet-postgres postgres -D /var/lib/postgresql/data -C shared_buffers
--   docker restart treepnet-postgres
-- then, in the treepnet database: create extension if not exists pg_stat_statements;
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < postgres_tuning.sql
-- Undo: postgres_tuning_rollback.sql (+ restart).

alter system set shared_buffers = '2GB';
alter system set effective_cache_size = '6GB';
alter system set work_mem = '16MB';
alter system set maintenance_work_mem = '256MB';
-- OCI block volumes are SSD-backed: a random read costs about a sequential one.
alter system set random_page_cost = 1.1;
alter system set effective_io_concurrency = 200;

-- Which queries take the time (normalized text, no values).
alter system set shared_preload_libraries = 'pg_stat_statements';
alter system set track_io_timing = on;
-- Statements over 1s go to the log — without their parameter values
-- (emails, codes), only the statement text.
alter system set log_min_duration_statement = '1s';
alter system set log_parameter_max_length = 0;

select pg_reload_conf();

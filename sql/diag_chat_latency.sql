-- Diagnose chat message delivery latency (was 1-3s, now 5-10s after push added).
-- Read-only.

\echo '== 1) push_outbox is it inside any publication (would flood PowerSync replication) =='
SELECT pubname FROM pg_publication_tables WHERE tablename = 'push_outbox';

\echo '== 2) publications: any FOR ALL TABLES? =='
SELECT pubname, puballtables FROM pg_publication;

\echo '== 3) which publication carries messages (the sync path) =='
SELECT pubname FROM pg_publication_tables WHERE tablename = 'messages';

\echo '== 4) is participants indexed on conversation_id (trigger runs this per message) =='
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'participants';

\echo '== 5) push_outbox size + status spread (unbounded growth / churn) =='
SELECT status, count(*) FROM public.push_outbox GROUP BY status ORDER BY 2 DESC;
SELECT count(*) AS total_rows FROM public.push_outbox;

\echo '== 6) logical replication slots — how far PowerSync is behind (the real latency signal) =='
SELECT slot_name, plugin, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS behind
FROM pg_replication_slots;

\echo '== 7) trigger cost sanity: how many participants rows total =='
SELECT count(*) AS participants_rows FROM public.participants;

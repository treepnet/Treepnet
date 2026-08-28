\echo === push_outbox ustunlari ===
SELECT column_name, data_type FROM information_schema.columns WHERE table_name='push_outbox' ORDER BY ordinal_position;
\echo === push_outbox ga yozadigan triggerlar ===
SELECT event_object_table AS on_table, trigger_name, action_timing, event_manipulation
FROM information_schema.triggers
WHERE action_statement ILIKE '%push%' OR trigger_name ILIKE '%push%'
ORDER BY 1,2;
\echo === profiles.push_token bor mi ===
SELECT count(*) AS with_token FROM profiles WHERE push_token IS NOT NULL AND push_token <> '';

INSERT INTO push_outbox (recipient_id, actor_id, type, title, body, data, status)
SELECT id, id, 'test', 'Test', 'pipeline test', '{}'::jsonb, 'pending'
FROM profiles WHERE (push_token IS NULL OR push_token = '') LIMIT 1
RETURNING id, status;

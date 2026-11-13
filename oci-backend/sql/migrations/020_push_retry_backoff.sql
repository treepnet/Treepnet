-- When a push that didn't go through is tried again.
--
-- The push worker retried every 15 s, five times: a short FCM outage (429 /
-- 503) dropped those pushes for good within about a minute. It now waits
-- 15 s, 1 min, 5 min, then 30 min (or longer, if FCM's Retry-After says so)
-- and stores the time here (functions/push-worker/push-worker.js). Null: due
-- now (new rows, and rows from before).

alter table public.push_outbox add column if not exists next_attempt_at timestamptz;

-- The push worker resets pushes stuck in 'sending' (a worker that died
-- mid-send) before every batch: on each new push and every 15 s. Nothing
-- indexed status = 'sending', so each reset read the whole queue (a year of
-- pushes). Only a handful are ever 'sending'.
create index if not exists push_outbox_sending_idx
  on public.push_outbox (claimed_at)
  where status = 'sending';

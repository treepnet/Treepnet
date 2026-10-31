-- Wake the push worker the moment a push is queued.
--
-- The worker used to poll push_outbox every 15 s, so a push could arrive up to
-- 15 s late. Every insert now sends NOTIFY push_outbox — at commit, so the
-- worker never looks before the row is there — and the worker (LISTEN
-- push_outbox, functions/push-worker) sends at once. The 15 s poll stays as a
-- fallback and for retries.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet \
--     -v ON_ERROR_STOP=1 < push_outbox_notify.sql
-- Undo: drop trigger push_outbox_notify on public.push_outbox;
--       drop function public.notify_push_outbox();

begin;

create or replace function public.notify_push_outbox()
returns trigger
language plpgsql
as $$
begin
  perform pg_notify('push_outbox', '');
  return null;
end;
$$;

revoke all on function public.notify_push_outbox() from public;

drop trigger if exists push_outbox_notify on public.push_outbox;
create trigger push_outbox_notify
  after insert on public.push_outbox
  for each statement execute function public.notify_push_outbox();

commit;

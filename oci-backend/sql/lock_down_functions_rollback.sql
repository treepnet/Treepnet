-- Undoes lock_down_functions.sql, restoring the earlier (open) privileges.
-- Only for an emergency, e.g. if likes or comments start failing after it.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < lock_down_functions_rollback.sql

begin;

alter table public.push_outbox disable row level security;
grant all on table public.push_outbox to authenticated;

alter default privileges for role treepnet
  grant execute on functions to public;
alter default privileges for role treepnet in schema public
  grant execute on functions to authenticated;

grant execute on all functions in schema public to public, authenticated;

alter function public.trg_push_on_comment() security invoker reset search_path;
alter function public.trg_push_on_like() security invoker reset search_path;
alter function public.trg_push_on_message() security invoker reset search_path;
alter function public.trg_push_on_subscription() security invoker reset search_path;
alter function public.enqueue_push(uuid, uuid, text, text, text, jsonb)
  security invoker reset search_path;
alter function public.push_actor_name(uuid) reset search_path;

commit;

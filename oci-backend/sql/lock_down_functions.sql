-- Close the database's internal functions and the push queue to app users.
--
-- Before: every public function was executable by `authenticated` — and
-- PostgREST's anonymous role IS `authenticated` — so anyone could call, with no
-- login, e.g. `delete_account_by_id` (deletes any account) or
-- `refresh_referral_tier` through /rpc. `push_outbox` had no RLS and full CRUD
-- for `authenticated`: anyone could read other people's notification texts,
-- queue fake pushes to anyone, or wipe the queue.
--
-- After: app users can execute only the two functions the app calls
-- (`delete_account`, `redeem_referral`). Functions created later are no longer
-- executable by them by default. `push_outbox` is closed to them entirely.
--
-- Order matters. The push triggers run as the user who likes / comments /
-- follows / messages, and they call `push_actor_name` and `enqueue_push`, which
-- insert into `push_outbox`. They become SECURITY DEFINER first, so they keep
-- working once those are closed — otherwise every like, comment, follow and
-- message would be rejected. (Triggers themselves fire regardless of EXECUTE
-- privilege; only the nested calls are checked.)
--
-- Unaffected: the push worker, delete-account and auth services connect as the
-- owner; `analytics_ro` only reads tables; no RLS policy, view or column default
-- calls these functions (checked on prod 2026-10-30).
--
-- Undo: lock_down_functions_rollback.sql.
-- Apply as the DB superuser:
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < lock_down_functions.sql

begin;

-- 1. The push chain runs as the owner.
alter function public.trg_push_on_comment() security definer set search_path = public;
alter function public.trg_push_on_like() security definer set search_path = public;
alter function public.trg_push_on_message() security definer set search_path = public;
alter function public.trg_push_on_subscription() security definer set search_path = public;
alter function public.enqueue_push(uuid, uuid, text, text, text, jsonb)
  security definer set search_path = public;
alter function public.push_actor_name(uuid) set search_path = public;

-- 2. Only the app's two RPCs stay callable by app users. (Functions are
--    executable by PUBLIC unless revoked from it too.)
revoke execute on all functions in schema public from public, authenticated;
grant execute on function public.delete_account() to authenticated;
grant execute on function public.redeem_referral(text) to authenticated;

-- 3. Functions created later are not callable by app users by default.
alter default privileges for role treepnet in schema public
  revoke execute on functions from authenticated;
alter default privileges for role treepnet
  revoke execute on functions from public;

-- 4. The push queue: only the owner (push worker, triggers) uses it.
alter table public.push_outbox enable row level security;
revoke all on table public.push_outbox from authenticated;

commit;

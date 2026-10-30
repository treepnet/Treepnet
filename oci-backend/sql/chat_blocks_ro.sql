-- Let the chat server know about blocks — and nothing else.
--
-- Blocks live here (blocked_users, main database); the chat server has its own
-- database and didn't know about them, so a blocked person could still open a
-- chat, send messages and trigger push notifications whenever the app's own
-- gate was bypassed (old app, a thread opened before the block, the API).
--
-- blocked_between(a, b) answers one question: has either of the two blocked
-- the other? Role chat_blocks_ro may log in and call that function only — no
-- table is readable by it. The chat server checks it before opening a chat,
-- sending a message (and its push) or forwarding "typing".
--
-- The password comes from the server .env (CHAT_BLOCKS_RO_PASS), never the repo,
-- and reaches psql through the environment (not the command line):
--   export CHAT_BLOCKS_RO_PASS=...   # from ~/treepnet/.env
--   docker exec -i -e CHAT_BLOCKS_RO_PASS treepnet-postgres psql -U <super> -d treepnet \
--     -v ON_ERROR_STOP=1 < chat_blocks_ro.sql
-- Undo: drop function public.blocked_between(uuid, uuid); drop role chat_blocks_ro;

\getenv pass CHAT_BLOCKS_RO_PASS
\if :{?pass}
\else
  \echo 'CHAT_BLOCKS_RO_PASS is not set'
  \quit
\endif

begin;

create or replace function public.blocked_between(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from blocked_users
     where (blocker_id = a and blocked_id = b)
        or (blocker_id = b and blocked_id = a)
  )
$$;

select format('create role chat_blocks_ro login password %L', :'pass')
 where not exists (select 1 from pg_roles where rolname = 'chat_blocks_ro')
\gexec
alter role chat_blocks_ro password :'pass';

grant connect on database treepnet to chat_blocks_ro;
grant usage on schema public to chat_blocks_ro;
revoke all on function public.blocked_between(uuid, uuid) from public, authenticated;
grant execute on function public.blocked_between(uuid, uuid) to chat_blocks_ro;

commit;

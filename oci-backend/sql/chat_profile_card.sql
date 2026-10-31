-- Where the chat server gets a user's name and avatar — and nothing else.
--
-- The chat server used to store whatever name and avatar the app sent: a
-- user's own (x-name / x-avatar headers) and, when opening a chat with someone
-- who had never used chat, that person's too (peerName / peerAvatar). So anyone
-- could show up in push notifications and chat lists under any name — another
-- user's, or "Treepnet Support". It now reads them from profiles instead.
--
-- chat_profile_card(id) returns only the username and avatar_url of one
-- profile. Like blocked_between (chat_blocks_ro.sql), only role chat_blocks_ro
-- may call it — the chat server's existing connection — and no table is
-- readable by that role.
--
-- Apply after chat_blocks_ro.sql (it creates the role):
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet \
--     -v ON_ERROR_STOP=1 < chat_profile_card.sql
-- Undo: drop function public.chat_profile_card(uuid);

begin;

create or replace function public.chat_profile_card(p_id uuid)
returns table (username text, avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
  select p.username, p.avatar_url from profiles p where p.id = p_id
$$;

revoke all on function public.chat_profile_card(uuid) from public, anon, authenticated;
grant execute on function public.chat_profile_card(uuid) to chat_blocks_ro;

commit;

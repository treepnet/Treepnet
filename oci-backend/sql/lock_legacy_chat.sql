-- Empty and lock the old PowerSync chat tables (step 1 of 2).
--
-- Direct messages moved to the self-hosted chat server (lib/chat) and its own
-- database; PowerSync stopped syncing these tables on 2026-10-10. They were
-- still open to every signed-in user over the REST API — anyone could read
-- every old private message, delete any conversation, or add a message to
-- one — and the push_on_message trigger turned such a message into a real
-- push notification to the other people in it. Their content was test data
-- only and isn't wanted (2026-11-01).
--
-- The tables stay, empty and closed, until the app version without the old
-- chat is in the stores: the version there now still has it, and writing to a
-- table that's gone fails in a way its upload queue retries forever (stuck
-- posts and likes), while "permission denied" (42501) is dropped at once.
-- Step 2, after that release: drop_legacy_chat.sql.
--   docker exec -i treepnet-postgres psql -U treepnet -d treepnet \
--     -v ON_ERROR_STOP=1 < lock_legacy_chat.sql
-- The deleted rows come back only from a backup taken before today.

begin;

drop trigger if exists push_on_message on public.messages;
drop function if exists public.trg_push_on_message();

truncate public.message_reactions,
         public.conversation_reads,
         public.typing_status,
         public.attachments,
         public.messages,
         public.participants,
         public.conversations;

revoke all on public.message_reactions,
              public.conversation_reads,
              public.typing_status,
              public.attachments,
              public.messages,
              public.participants,
              public.conversations
  from authenticated, anon, public;

commit;

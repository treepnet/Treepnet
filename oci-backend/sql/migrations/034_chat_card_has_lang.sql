-- The chat server's card of a person carries their app language.
--
-- The chat sent its pushes in the language of the x-lang header it had
-- stored: 'uz' on most rows (so English), and a socket reconnect wrote an
-- old language back after the app's had changed. profiles.lang is the one
-- the app keeps up to date; the chat server now reads it here, with the
-- username and avatar it already did (P3 #183).
--
-- The result gains a column, which CREATE OR REPLACE can't do: dropped and
-- made again in this one transaction, with the same rights (the owner, and
-- chat_blocks_ro, the chat server's read-only login). The running chat
-- server selects username and avatar_url by name, so it is unaffected.

drop function public.chat_profile_card(uuid);

create function public.chat_profile_card(p_id uuid)
 returns table(username text, avatar_url text, lang text)
 language sql
 stable security definer
 set search_path to 'public'
as $function$
  select p.username, p.avatar_url, p.lang from profiles p where p.id = p_id
$function$;

revoke all on function public.chat_profile_card(uuid) from public, anon, authenticated;
grant execute on function public.chat_profile_card(uuid) to chat_blocks_ro;

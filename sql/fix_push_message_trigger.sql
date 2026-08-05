-- FIX: trg_push_on_message() used COALESCE(NEW.is_deleted, false), but in this
-- database messages.is_deleted is an INTEGER (0/1), not boolean. So every
-- message INSERT raised "COALESCE types integer and boolean cannot be matched",
-- the INSERT failed, and the whole PowerSync upload queue jammed (no chat
-- message could reach the server). Compare is_deleted as an integer instead.

CREATE OR REPLACE FUNCTION public.trg_push_on_message()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor text;
  r RECORD;
BEGIN
  IF COALESCE(NEW.is_deleted, 0) <> 0 THEN RETURN NEW; END IF;
  v_actor := public.push_actor_name(NEW.from_id);
  FOR r IN
    SELECT user_id
    FROM public.participants
    WHERE conversation_id = NEW.conversation_id
      AND user_id <> NEW.from_id
  LOOP
    PERFORM public.enqueue_push(
      r.user_id, NEW.from_id, 'message',
      v_actor, left(COALESCE(NEW.message, ''), 140),
      jsonb_build_object('type','message','actor_id',NEW.from_id,
                         'conversation_id',NEW.conversation_id)
    );
  END LOOP;
  RETURN NEW;
END;
$$;

\echo 'trg_push_on_message tuzatildi. Endi xabar INSERT ishlashi kerak — sinov:'
BEGIN;
INSERT INTO public.messages
  (id, conversation_id, from_id, type, message, created_at, updated_at,
   is_read, is_deleted, is_edited, from_username)
VALUES
  ('4f42d01e-6537-40d0-a57b-5ac313da068d',
   '5ec9964c-e450-4a03-bcbc-6a72afa3c555',
   '65b08892-e188-4064-b788-c6b1f196e856',
   'text', 'Hello', '2026-08-05T16:31:29.096787', '2026-08-05T16:31:29.096869',
   0, 0, 0, 'anabella_z');
ROLLBACK;
\echo 'Yuqorida "INSERT 0 1" chiqsa — tuzatildi (ROLLBACK qilindi, hech narsa saqlanmadi).'

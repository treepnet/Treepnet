-- Push notifications: enqueue side (Postgres).
--
-- Every like / comment / follow(-request) / chat message that lands in Postgres
-- (via PowerSync → PostgREST) fires an AFTER INSERT trigger that writes ONE row
-- into `push_outbox`. A separate Azure Function polls this table, looks up the
-- recipient's `profiles.push_token`, sends via FCM HTTP v1, and marks the row.
--
-- These tables are backend-only: they are NOT added to any PowerSync publication,
-- so clients never sync them. See New TreepNet/PUSH_NOTIFICATIONS_PLAN.md.
--
-- Idempotent: safe to re-run.

-- ---------------------------------------------------------------------------
-- Outbox
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.push_outbox (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL,
  actor_id     uuid,
  type         text NOT NULL,          -- like | comment | follow | follow_request | message
  title        text,
  body         text,
  data         jsonb NOT NULL DEFAULT '{}'::jsonb,
  status       text NOT NULL DEFAULT 'pending',  -- pending | sending | sent | failed
  attempts     int  NOT NULL DEFAULT 0,
  last_error   text,
  created_at   timestamptz NOT NULL DEFAULT now(),
  claimed_at   timestamptz,                       -- set when a Function run picks it up
  sent_at      timestamptz
);

-- Older deployments: add the column if the table already existed.
ALTER TABLE public.push_outbox ADD COLUMN IF NOT EXISTS claimed_at timestamptz;

-- The Function's hot query: oldest pending first.
CREATE INDEX IF NOT EXISTS push_outbox_pending_idx
  ON public.push_outbox (created_at)
  WHERE status = 'pending';

-- ---------------------------------------------------------------------------
-- Helper: enqueue only when recipient != actor and recipient has a token.
-- (Token existence is re-checked by the Function; this just trims obvious noise.)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enqueue_push(
  p_recipient uuid,
  p_actor     uuid,
  p_type      text,
  p_title     text,
  p_body      text,
  p_data      jsonb
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_recipient IS NULL OR p_recipient = p_actor THEN
    RETURN;
  END IF;
  INSERT INTO public.push_outbox (recipient_id, actor_id, type, title, body, data)
  VALUES (p_recipient, p_actor, p_type, p_title, p_body, COALESCE(p_data, '{}'::jsonb));
END;
$$;

-- Actor's display name for the title.
CREATE OR REPLACE FUNCTION public.push_actor_name(p_actor uuid)
RETURNS text
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(NULLIF(username, ''), NULLIF(full_name, ''), 'Someone')
  FROM public.profiles WHERE id = p_actor;
$$;

-- ---------------------------------------------------------------------------
-- likes → notify the post owner
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_like()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner uuid;
  v_actor text;
BEGIN
  IF NEW.post_id IS NULL THEN RETURN NEW; END IF;
  SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
  IF v_owner IS NULL THEN RETURN NEW; END IF;
  v_actor := public.push_actor_name(NEW.user_id);
  PERFORM public.enqueue_push(
    v_owner, NEW.user_id, 'like',
    v_actor, 'liked your post',
    jsonb_build_object('type','like','actor_id',NEW.user_id,'post_id',NEW.post_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_on_like ON public.likes;
CREATE TRIGGER push_on_like
  AFTER INSERT ON public.likes
  FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_like();

-- ---------------------------------------------------------------------------
-- comments → notify the post owner
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_comment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_owner uuid;
  v_actor text;
BEGIN
  IF NEW.post_id IS NULL THEN RETURN NEW; END IF;
  SELECT user_id INTO v_owner FROM public.posts WHERE id = NEW.post_id;
  IF v_owner IS NULL THEN RETURN NEW; END IF;
  v_actor := public.push_actor_name(NEW.user_id);
  PERFORM public.enqueue_push(
    v_owner, NEW.user_id, 'comment',
    v_actor, 'commented: ' || left(COALESCE(NEW.content, ''), 120),
    jsonb_build_object('type','comment','actor_id',NEW.user_id,'post_id',NEW.post_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_on_comment ON public.comments;
CREATE TRIGGER push_on_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_comment();

-- ---------------------------------------------------------------------------
-- subscriptions → notify the followed user
--   pending  = follow request (private account)
--   accepted = plain new follower (public account)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_subscription()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor text;
  v_type  text;
  v_body  text;
BEGIN
  v_actor := public.push_actor_name(NEW.subscriber_id);
  IF NEW.status = 'pending' THEN
    v_type := 'follow_request';
    v_body := 'requested to follow you';
  ELSE
    v_type := 'follow';
    v_body := 'started following you';
  END IF;
  PERFORM public.enqueue_push(
    NEW.subscribed_to_id, NEW.subscriber_id, v_type,
    v_actor, v_body,
    jsonb_build_object('type',v_type,'actor_id',NEW.subscriber_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS push_on_subscription ON public.subscriptions;
CREATE TRIGGER push_on_subscription
  AFTER INSERT ON public.subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_subscription();

-- ---------------------------------------------------------------------------
-- messages → notify the other participant(s) of the conversation
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.trg_push_on_message()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_actor text;
  r RECORD;
BEGIN
  -- is_deleted is an integer (0/1) in this schema, not boolean.
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

DROP TRIGGER IF EXISTS push_on_message ON public.messages;
CREATE TRIGGER push_on_message
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.trg_push_on_message();

-- ---------------------------------------------------------------------------
-- Access: the Azure Function connects as an admin/owner role (same as the
-- delete-account function), so no extra GRANTs are needed here. If you point it
-- at a limited role instead, grant that role SELECT/UPDATE on push_outbox and
-- SELECT on profiles. push_outbox is intentionally OUTSIDE any PowerSync
-- publication so it never syncs to clients.
-- ---------------------------------------------------------------------------

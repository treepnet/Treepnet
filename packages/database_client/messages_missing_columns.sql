-- FIX: PowerSync uploads were failing forever with
--   "Could not find the 'reply_message_message' column of 'messages'"
-- which blocks the WHOLE upload queue (no posts, saves, chats reach the
-- server). The Dart schema (packages/shared/lib/src/models/schema.dart)
-- declares these columns, so Postgres must have them too.
--
-- Safe to re-run.

alter table public.messages
  add column if not exists reply_message_message      text,
  add column if not exists reply_message_username     text,
  add column if not exists reply_message_attachment_url text,
  add column if not exists reply_message_id           uuid,
  add column if not exists shared_post_id             uuid,
  add column if not exists from_username              text,
  add column if not exists is_read                    boolean default false,
  add column if not exists is_deleted                 boolean default false,
  add column if not exists is_edited                  boolean default false,
  add column if not exists updated_at                 timestamptz;

notify pgrst, 'reload schema';

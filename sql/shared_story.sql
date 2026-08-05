-- "Share a story into a DM": a message can point at a story, rendered as a
-- tappable preview in chat (like shared posts do with shared_post_id).
-- messages already syncs via `select *` in the user_conversations bucket, so
-- this column syncs with no sync-rule change. Stories are globally synced, so
-- the recipient already has the story row to render.

alter table public.messages
  add column if not exists shared_story_id uuid;

notify pgrst, 'reload schema';

-- The server refuses a post caption or a comment longer than the app lets
-- anyone write — so a script or an old build can't store a novel.
--
-- NOT YET: apply only once the build with the app's own limits (2200 for a
-- caption, 1000 for a comment; lib/app/view/text_limit.dart) is what people
-- use. An older build can still send longer text, and the server refusing it
-- drops that post or comment from the phone's upload queue.
--
-- To apply: move this file to ../migrations/ as the next number
-- (e.g. 002_text_length_limits.sql) and run ./migrate.sh --dry-run, then
-- ./migrate.sh on the server.
--
-- The limits are twice the app's: the app counts characters as you see them,
-- Postgres counts code points, and one emoji can be several (👨‍👩‍👧 is five).

alter table public.posts
  add constraint posts_caption_length
  check (char_length(coalesce(caption, '')) <= 4400) not valid;
alter table public.posts validate constraint posts_caption_length;

alter table public.comments
  add constraint comments_content_length
  check (char_length(content) <= 2000) not valid;
alter table public.comments validate constraint comments_content_length;

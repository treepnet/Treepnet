-- The server refuses text longer than the app lets anyone write, so a script
-- or an old build can't store a novel: what one account writes in these
-- fields syncs to its followers and comes back in search, follow lists and
-- the feed for everyone, bloating phones' databases, sync traffic and
-- backups.
--
-- The limits are at least twice the app's: the app counts characters as you
-- see them, Postgres counts code points, and one emoji can be several (👨‍👩‍👧 is
-- five) — more room for the short names, where a row of emoji is likely.
--
--   field                          app            server
--   posts.caption                  2200           4400
--   comments.content               1000           2000
--   profiles.bio                    150            300
--   profiles.full_name               40             80
--   profiles.website                100            200
--   profiles.instagram/telegram   30/32            100
--   posts/stories.location_name     100            300
--   story_highlights.name            30            150
--   posts.media (JSON, ≤10 items)     -          20000
--
-- Older builds have no limit on some of these (caption and comment until the
-- limits of 2026-11-01, highlight and place names until this change); text
-- past the server's limit is refused and dropped from that phone's upload
-- queue. On 2026-11-13 the longest values were tiny (bio 46, caption 65,
-- place 32, highlight 11, media 4,181).
--
-- NOT VALID then VALIDATE: the check is in place at once, and the existing
-- rows are checked without a long lock.

alter table public.posts
  add constraint posts_caption_length
  check (char_length(coalesce(caption, '')) <= 4400) not valid;
alter table public.posts validate constraint posts_caption_length;

alter table public.comments
  add constraint comments_content_length
  check (char_length(content) <= 2000) not valid;
alter table public.comments validate constraint comments_content_length;

alter table public.profiles
  add constraint profiles_text_lengths
  check (
    char_length(coalesce(bio, '')) <= 300
    and char_length(coalesce(full_name, '')) <= 80
    and char_length(coalesce(website, '')) <= 200
    and char_length(coalesce(instagram, '')) <= 100
    and char_length(coalesce(telegram, '')) <= 100
  ) not valid;
alter table public.profiles validate constraint profiles_text_lengths;

alter table public.posts
  add constraint posts_location_name_length
  check (char_length(coalesce(location_name, '')) <= 300) not valid;
alter table public.posts validate constraint posts_location_name_length;

alter table public.posts
  add constraint posts_media_length
  check (char_length(coalesce(media, '')) <= 20000) not valid;
alter table public.posts validate constraint posts_media_length;

alter table public.stories
  add constraint stories_location_name_length
  check (char_length(coalesce(location_name, '')) <= 300) not valid;
alter table public.stories validate constraint stories_location_name_length;

alter table public.story_highlights
  add constraint story_highlights_name_length
  check (char_length(coalesce(name, '')) <= 150) not valid;
alter table public.story_highlights validate constraint story_highlights_name_length;

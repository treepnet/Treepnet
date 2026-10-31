-- Point every stored photo URL at the media.treepnet.com CDN.
--
-- ROLLED BACK 2026-10-31 (media_cdn_urls_rollback.sql): Russian ISPs throttle
-- Cloudflare to the first ~16 KB of each file. Don't re-apply without a CDN
-- that is reachable from Russia.
--
-- Before: posts, stories, highlight covers and avatars stored the bucket's own
-- URL, so every phone downloaded every photo from Frankfurt, each time it
-- wasn't in the phone's cache.
--
-- After: they store https://media.treepnet.com/<object>, which the Cloudflare
-- Worker in oci-backend/media-cdn serves from the nearest edge (the bucket is
-- only read on a miss). The object names are the same, so nothing is copied or
-- moved, and the old URLs keep working. New uploads get the CDN URL from the
-- app (MediaStorage.getPublicUrl). Phones re-download each photo once, under
-- its new URL.
--
-- Apply the delete_account_by_id from account_deletion_cleanup.sql first: it
-- recognises both URL forms, so a deleted account's photos are still removed.
--
-- Undo: media_cdn_urls_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < media_cdn_urls.sql

begin;

update public.posts
   set media = replace(media,
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/',
         'https://media.treepnet.com/')
 where media like '%https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/%';

update public.stories
   set content_url = replace(content_url,
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/',
         'https://media.treepnet.com/')
 where content_url like 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/%';

update public.story_highlights
   set cover_url = replace(cover_url,
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/',
         'https://media.treepnet.com/')
 where cover_url like 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/%';

update public.profiles
   set avatar_url = replace(avatar_url,
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/',
         'https://media.treepnet.com/')
 where avatar_url like 'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/%';

commit;

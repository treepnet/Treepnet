-- Undoes media_cdn_urls.sql: stored photo URLs point at the bucket directly
-- again (e.g. if the media.treepnet.com Worker has to be taken down). Uploads
-- made since by a CDN-aware app are switched back too.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < media_cdn_urls_rollback.sql

begin;

update public.posts
   set media = replace(media,
         'https://media.treepnet.com/',
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/')
 where media like '%https://media.treepnet.com/%';

update public.stories
   set content_url = replace(content_url,
         'https://media.treepnet.com/',
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/')
 where content_url like 'https://media.treepnet.com/%';

update public.story_highlights
   set cover_url = replace(cover_url,
         'https://media.treepnet.com/',
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/')
 where cover_url like 'https://media.treepnet.com/%';

update public.profiles
   set avatar_url = replace(avatar_url,
         'https://media.treepnet.com/',
         'https://objectstorage.eu-frankfurt-1.oraclecloud.com/n/fryarohmp0gm/b/treepnet-media/o/')
 where avatar_url like 'https://media.treepnet.com/%';

commit;

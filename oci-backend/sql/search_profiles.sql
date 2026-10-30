-- People search that understands Cyrillic and Latin alike.
--
-- Before: the app stripped everything but ASCII letters, digits and - _ . +
-- from a query and sent it as a PostgREST filter, so "Иван" became an empty
-- search (random users came back), "First Last" lost its space, and names
-- like "Ra'no" or "Gʻulom" lost the apostrophe.
--
-- After: search_profiles(query) compares a search key of the query with the
-- same key of each username and name:
--   * lower-cased, whitespace collapsed, apostrophes dropped;
--   * Cyrillic (Russian and Uzbek) spelled in Latin: Иван -> ivan,
--     Шаҳзод -> shahzod, Ёрқин -> yorqin;
--   * common double spellings folded: kh / x -> h, zh -> j.
-- So Latin finds Cyrillic and the other way round. Names starting with the
-- query come first. The query is a parameter (no filter string to break) and
-- its % and _ match literally. The caller is never in the results; blocks are
-- still filtered in the app. The app's offline search uses the same key
-- (database_client.dart `_searchKey`) — keep the two in step.
--
-- Undo: drop function public.search_profiles(text, int, int); drop function public.search_key(text);
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < search_profiles.sql

begin;

create or replace function public.search_key(p text)
returns text
language sql
immutable
parallel safe
set search_path = public
as $$
  select replace(replace(replace(
           translate(
             replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
               lower(btrim(regexp_replace(coalesce(p, ''), '\s+', ' ', 'g'))),
               'щ', 'sh'), 'ш', 'sh'), 'ч', 'ch'), 'ц', 'ts'), 'ю', 'yu'),
               'я', 'ya'), 'ё', 'yo'), 'ж', 'j'), 'х', 'h'), 'ҳ', 'h'),
             -- one letter for one; the rest (ъ ь and apostrophes) are dropped
             'абвгдезийклмнопрстуфыэўқғъь''’ʻʼ`',
             'abvgdeziyklmnoprstufieoqg'),
           'kh', 'h'), 'zh', 'j'), 'x', 'h')
$$;

create or replace function public.search_profiles(
  p_query text,
  p_limit int default 8,
  p_offset int default 0
)
returns table (id uuid, avatar_url text, full_name text, username text)
language sql
stable
security definer
set search_path = public
as $$
  with q as (
    select replace(replace(replace(public.search_key(p_query),
             '\', '\\'), '%', '\%'), '_', '\_') as k
  )
  select p.id, p.avatar_url, p.full_name, p.username
    from profiles p, q
   where q.k <> ''
     and p.id is distinct from auth.uid()
     and (public.search_key(p.username) like '%' || q.k || '%' escape '\'
          or public.search_key(p.full_name) like '%' || q.k || '%' escape '\')
   order by (public.search_key(p.username) like q.k || '%' escape '\'
             or public.search_key(p.full_name) like q.k || '%' escape '\') desc,
            p.username
   limit least(greatest(coalesce(p_limit, 8), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

revoke all on function public.search_key(text) from public, authenticated;
revoke all on function public.search_profiles(text, int, int) from public, authenticated;
grant execute on function public.search_profiles(text, int, int) to authenticated;

commit;

-- PostgREST picks up the new function.
notify pgrst, 'reload schema';

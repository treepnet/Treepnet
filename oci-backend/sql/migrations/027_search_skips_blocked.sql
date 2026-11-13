-- People search leaves out anyone blocked either way.
--
-- search_profiles didn't know about blocks: the app dropped blocked people
-- from each page after the server had paged it, so a page came back shorter
-- than asked and the app took that for the end of the results (search
-- stopped early for anyone who had blocked someone). Now the server leaves
-- them out before paging. The app's own filter stays and finds nothing.
--
-- Blocks can't be kept off the phone in the sync streams the same way: the
-- Sync Streams compiler refuses "NOT IN" on a parameter subquery (tried both
-- ways, 2026-11-13); server reads already go through can_view_author().

create or replace function public.search_profiles(p_query text, p_limit integer default 8, p_offset integer default 0)
returns table(id uuid, avatar_url text, full_name text, username text)
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
     and not exists (
       select 1 from blocked_users b
        where (b.blocker_id = auth.uid() and b.blocked_id = p.id)
           or (b.blocker_id = p.id and b.blocked_id = auth.uid()))
   order by (public.search_key(p.username) like q.k || '%' escape '\'
             or public.search_key(p.full_name) like q.k || '%' escape '\') desc,
            p.username
   limit least(greatest(coalesce(p_limit, 8), 1), 50)
  offset greatest(coalesce(p_offset, 0), 0)
$$;

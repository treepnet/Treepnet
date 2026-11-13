-- One bad id no longer fails a whole profile_cards call.
--
-- The app asks for the cards of everyone it needs within 50 ms in one call
-- (names, avatars and badges of people whose profiles aren't on the phone).
-- p_ids was uuid[], so PostgREST cast the whole list before the function ran,
-- and one empty id (a profile page whose user hadn't loaded yet, in build
-- 1.0.8) made every card in that call fail: those people lost their name,
-- avatar and badge, or dropped out of lists. The app stopped sending such ids
-- after 1.0.8; this keeps 1.0.8 working. Now the ids come as text and anything
-- that isn't a UUID is skipped. Same name and argument, so callers don't
-- change; the old uuid[] version goes (two would be ambiguous to PostgREST).

drop function if exists public.profile_cards(uuid[]);

create function public.profile_cards(p_ids text[])
returns table (
  id uuid,
  username text,
  full_name text,
  avatar_url text,
  referral_tier integer,
  referral_tier_expires_at timestamptz,
  is_private boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select a.id, a.username, a.full_name, a.avatar_url, a.referral_tier,
         a.referral_tier_expires_at, a.is_private
    from profiles a
   where a.id = any (
     select x::uuid
       from unnest(p_ids[1:200]) x
      where x ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
$$;

revoke all on function public.profile_cards(text[]) from public, anon;
grant execute on function public.profile_cards(text[]) to authenticated;

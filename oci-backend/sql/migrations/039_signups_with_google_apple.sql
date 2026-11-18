-- An account made with Google or Apple is a sign-up like any other.
--
-- Two places told a new account by its password row, which an account made
-- with Google/Apple doesn't have (038):
--
--   * redeem_referral() counts an invite only for an account made within
--     the hour: for a Google/Apple account it always said 'too_late', so
--     whoever invited it got nothing.
--   * analytics.signups (the admin's sign-ups) had no Google/Apple ones.
--
-- Both now take the account's first sign-in method's date — the earlier of
-- the password row's and the first Google/Apple sign-in's: a password set
-- later (a reset), or Google tied to an old account, is no sign-up.

create or replace function public.redeem_referral(p_handle text)
 returns text
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_referrer uuid;
  v_me uuid := auth.uid();
  v_handle text := trim(coalesce(p_handle, ''));
  v_made timestamptz;
begin
  if v_me is null then
    return 'unauthenticated';
  end if;
  if length(v_handle) = 0 then
    return 'unknown';
  end if;
  -- Only a sign-up counts: the app redeems right after creating the account
  -- (with a password, or with Google/Apple).
  select least(
           (select created_at from auth_credentials where user_id = v_me),
           (select min(created_at) from auth_identities where user_id = v_me))
    into v_made;
  if v_made is null or v_made <= now() - interval '1 hour' then
    return 'too_late';
  end if;

  select id into v_referrer
    from public.profiles
   where username = v_handle
   limit 1;

  -- The link may carry the id instead of the username.
  if v_referrer is null then
    begin
      v_referrer := v_handle::uuid;
      if not exists (select 1 from public.profiles where id = v_referrer) then
        v_referrer := null;
      end if;
    exception when others then
      v_referrer := null;
    end;
  end if;

  if v_referrer is null then
    return 'unknown';
  end if;
  if v_referrer = v_me then
    return 'self';
  end if;

  insert into public.referrals (referrer_id, invited_id)
       values (v_referrer, v_me)
  on conflict (invited_id) do nothing;

  -- A conflict inserts nothing: this account was invited already.
  if not found then
    return 'already';
  end if;

  perform public.refresh_referral_tier(v_referrer);
  return 'ok';
end;
$function$;

-- One row per account, at its first sign-in method's date (as above).
create or replace view analytics.signups as
  select user_id, min(created_at) as created_at
    from (select user_id, created_at from public.auth_credentials
          union all
          select user_id, created_at from public.auth_identities) made
   group by user_id;

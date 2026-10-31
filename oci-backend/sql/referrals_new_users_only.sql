-- Referrals count only for brand-new accounts, and only through
-- redeem_referral; a referrer's badge follows when an invite goes away.
--
-- Before:
--   * redeem_referral never looked at the account's age: any account nobody
--     had invited could name anyone its referrer at any time (the "only new
--     sign-ups count" rule lived in the app alone);
--   * referrals could also be written straight through PostgREST (an INSERT
--     grant and the "Insert own invitation" policy), skipping the function;
--   * when an invited account was deleted its referral row went with it, but
--     the referrer's tier and premium end date weren't recomputed.
-- After:
--   * redeem_referral answers 'too_late' for an account created more than an
--     hour ago (the app redeems right after sign-up);
--   * clients can only read referrals; writes go through the function;
--   * deleting a referral row recomputes its referrer's tier.
--
-- Undo: referrals_new_users_only_rollback.sql.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < referrals_new_users_only.sql

begin;

create or replace function public.redeem_referral(p_handle text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
  v_me uuid := auth.uid();
  v_handle text := trim(coalesce(p_handle, ''));
begin
  if v_me is null then
    return 'unauthenticated';
  end if;
  if length(v_handle) = 0 then
    return 'unknown';
  end if;
  -- Only a sign-up counts: the app redeems right after creating the account.
  if not exists (
    select 1 from auth_credentials
     where user_id = v_me and created_at > now() - interval '1 hour'
  ) then
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
$$;

-- Writes only through redeem_referral (security definer).
drop policy if exists "Insert own invitation" on public.referrals;
revoke insert, update, delete, truncate on public.referrals from authenticated;

create or replace function public.referrals_refresh_referrer()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform refresh_referral_tier(old.referrer_id);
  return null;
end;
$$;

revoke all on function public.referrals_refresh_referrer() from public, authenticated;

drop trigger if exists referrals_refresh_referrer on public.referrals;
create trigger referrals_refresh_referrer
  after delete on public.referrals
  for each row execute function public.referrals_refresh_referrer();

commit;

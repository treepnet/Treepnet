-- Undoes referrals_new_users_only.sql: any account can redeem a referral at
-- any time, clients may insert their own invitation directly again, and
-- deleting a referral no longer recomputes the referrer's tier.
--   docker exec -i treepnet-postgres psql -U <super> -d treepnet -v ON_ERROR_STOP=1 < referrals_new_users_only_rollback.sql

begin;

drop trigger if exists referrals_refresh_referrer on public.referrals;
drop function if exists public.referrals_refresh_referrer();

grant insert, update, delete, truncate on public.referrals to authenticated;
drop policy if exists "Insert own invitation" on public.referrals;
create policy "Insert own invitation" on public.referrals
  for insert
  with check (auth.uid() = invited_id);

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

  select id into v_referrer
    from public.profiles
   where username = v_handle
   limit 1;

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

  if not found then
    return 'already';
  end if;

  perform public.refresh_referral_tier(v_referrer);
  return 'ok';
end;
$$;

commit;

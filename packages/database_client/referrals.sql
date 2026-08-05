-- ============================================================================
-- TreepNet — Referral / reward-badge backend.
--
-- SAFE to run on the live database: this script only ADDS things
-- (add-column-if-not-exists, create-table-if-not-exists, create-or-replace).
-- It NEVER drops a table or deletes data. Run it in the Supabase SQL editor.
--
-- After running: also add the `user_referrals` bucket from
-- packages/powersync_repository/sync_rules.txt to your PowerSync sync rules.
-- ============================================================================

-- 1) The highest badge tier the user has reached (0 = none, 1..6). Persisted
--    so a badge, once earned, is kept forever (never downgrades).
alter table public.profiles
  add column if not exists referral_tier int not null default 0;

-- 2) Who invited whom. Each user can be invited by at most one person
--    (first referral wins); a user can never refer themselves.
create table if not exists public.referrals (
  id          uuid primary key default gen_random_uuid(),
  referrer_id uuid not null references public.profiles (id) on delete cascade,
  invited_id  uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint referrals_invited_unique unique (invited_id),
  constraint referrals_no_self check (referrer_id <> invited_id)
);

create index if not exists referrals_referrer_idx
  on public.referrals (referrer_id, created_at);

alter table public.referrals enable row level security;

-- Both parties can read the row (the client counts its own invites to light up
-- the badge ladder).
drop policy if exists "See own referrals" on public.referrals;
create policy "See own referrals" on public.referrals
  for select using (auth.uid() = referrer_id or auth.uid() = invited_id);

-- A client may only record ITSELF as the invited party (the RPC below is the
-- normal path; this policy is a safety net for any direct insert).
drop policy if exists "Insert own invitation" on public.referrals;
create policy "Insert own invitation" on public.referrals
  for insert with check (auth.uid() = invited_id);

-- 3) Recompute and persist the highest tier reached. Never downgrades.
--    Reward rule (from the app): tier i is earned once at least (i * 10)
--    referrals fall within the last i months —
--      1 → 1 month / 10 people   (moviy)
--      2 → 2 months / 20 people  (to'q ko'k)
--      3 → 3 months / 30 people  (binafsha)
--      4 → 4 months / 40 people  (pushti)
--      5 → 5 months / 50 people  (qizil)
--      6 → 6 months / 60 people  (Qirol / toj)
create or replace function public.refresh_referral_tier(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier   int   := 0;
  v_people int[] := array[10, 20, 30, 40, 50, 60];
  i        int;
  v_count  int;
begin
  for i in 1..6 loop
    select count(*) into v_count
      from public.referrals
     where referrer_id = p_user
       and created_at >= now() - make_interval(months => i);
    if v_count >= v_people[i] then
      v_tier := i;
    end if;
  end loop;

  update public.profiles
     set referral_tier = greatest(referral_tier, v_tier)
   where id = p_user;
end;
$$;

-- 4) Called by a freshly signed-up user with the inviter's handle taken from
--    the invite link (https://treepnet.app/invite/<handle>). The handle may be
--    a username or a raw user id. Safe to call more than once (no-op after the
--    first). Ignores unknown handles and self-referrals.
--    Returns a status the app shows to the user: 'ok' (recorded), 'already'
--    (already invited before), 'self' (own code), or 'unknown' (no such user).
create or replace function public.redeem_referral(p_handle text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_referrer uuid;
  v_inserted int;
begin
  if auth.uid() is null or p_handle is null or length(trim(p_handle)) = 0 then
    return 'unknown';
  end if;

  -- Resolve by username first, then fall back to a raw user id.
  select id into v_referrer
    from public.profiles
   where username = p_handle
   limit 1;

  if v_referrer is null then
    begin
      v_referrer := p_handle::uuid;
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
  if v_referrer = auth.uid() then
    return 'self';
  end if;

  insert into public.referrals (referrer_id, invited_id)
       values (v_referrer, auth.uid())
  on conflict (invited_id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return 'already';
  end if;

  perform public.refresh_referral_tier(v_referrer);
  return 'ok';
end;
$$;

grant execute on function public.redeem_referral(text) to authenticated;

-- Optional: recompute everyone's tier on demand (e.g. from a scheduled job) so
-- windows that just crossed a threshold are reflected without a new referral.
--   select public.refresh_referral_tier(id) from public.profiles;

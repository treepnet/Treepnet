-- ============================================================================
-- TreepNet — invite-bought premium, travel-coloured checkmark.
--
-- SAFE to run on the live database: it only ADDS a column, replaces functions
-- and adds a trigger. It never drops a table or deletes a row.
-- Re-runnable: running it twice changes nothing.
--
-- ⚠ REQUIRED. The app reads profiles.referral_tier_expires_at; until the
--   column exists, no checkmark is shown to anyone.
--
-- THE RULE — two independent halves
--
--   HOW LONG (invites): every 5 accepted invites add 1 month of premium, and
--   the months stack. 50 invites = 10 months. The checkmark is visible only
--   while premium is running, so it lapses unless the user keeps inviting.
--
--   WHICH COLOUR (travel): locations added ÷ regions visited —
--       < 10 → blue      20-29 → violet     40+ → red
--      10-19 → dark blue  30-39 → pink
--   Posts do not count toward the colour beyond being the locations
--   themselves. A single region has no spread to measure, so its locations are
--   halved instead — otherwise one busy city would read as deep exploration.
--
--   The checkmark also stays hidden until at least one post carries a location.
--
-- WHY THE SERVER COMPUTES IT
--   `referrals` syncs only to the person who owns those invites, so a device
--   cannot work out anyone else's premium. The result is published on the
--   globally-synced profile instead; the app re-checks the end date locally so
--   a checkmark disappears on time even between server runs.
-- ============================================================================

-- 1) When premium runs out. NULL = none.
alter table public.profiles
  add column if not exists referral_tier_expires_at timestamptz;

-- 2) Same signature as before so existing callers keep working. Note that
--    referral_tier now holds the travel COLOUR (1-5), not an invite rank.
create or replace function public.refresh_referral_tier(p_user uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier      int := 0;
  v_locations int;
  v_regions   int;
  v_ratio     numeric;
  v_end       timestamptz := null;
  r           record;
begin
  -- Colour: how widely they explore.
  select count(*) filter (where location_lat is not null),
         count(distinct location_region)
           filter (where location_region is not null and location_region <> '')
    into v_locations, v_regions
    from public.posts
   where user_id = p_user;

  if v_locations > 0 and v_regions > 0 then
    v_ratio := case
                 when v_regions >= 2 then v_locations::numeric / v_regions
                 else v_locations::numeric / 2
               end;
    v_tier := case
                when v_ratio < 10 then 1
                when v_ratio < 20 then 2
                when v_ratio < 30 then 3
                when v_ratio < 40 then 4
                else 5
              end;
  end if;

  -- Duration: every 5th invite tops the subscription up by a month, extending
  -- the balance rather than restarting it.
  for r in
    select created_at,
           row_number() over (order by created_at) as rn
      from public.referrals
     where referrer_id = p_user
     order by created_at
  loop
    if r.rn % 5 = 0 then
      v_end := greatest(coalesce(v_end, r.created_at), r.created_at)
                 + interval '1 month';
    end if;
  end loop;

  -- Nothing on the map means nothing to show, however much premium is banked.
  if v_locations = 0 then
    v_tier := 0;
  end if;

  update public.profiles
     set referral_tier            = v_tier,
         referral_tier_expires_at = v_end
   where id = p_user;
end;
$$;

-- 3) Posts decide the colour, so any change to them can change it — including
--    a delete, which is why OLD is handled too.
create or replace function public.posts_refresh_referral_tier()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_referral_tier(old.user_id);
    return old;
  end if;
  perform public.refresh_referral_tier(new.user_id);
  return new;
end;
$$;

drop trigger if exists posts_refresh_referral_tier on public.posts;
create trigger posts_refresh_referral_tier
  after insert or delete
     or update of location_lat, location_region on public.posts
  for each row execute function public.posts_refresh_referral_tier();

-- 4) Re-evaluate everyone once, so colours and end dates are filled in.
select public.refresh_referral_tier(id) from public.profiles;

-- 5) REQUIRED for expiry to be reflected server-side: nothing else re-runs the
--    check once premium runs out. Schedule step 4 daily (pg_cron):
--   create extension if not exists pg_cron;
--   select cron.schedule(
--     'refresh-referral-tiers', '0 3 * * *',
--     $cron$ select public.refresh_referral_tier(id) from public.profiles $cron$
--   );
--   (The app also hides a lapsed checkmark on its own, so a missed run only
--    delays the server's copy, never shows one that should be gone.)

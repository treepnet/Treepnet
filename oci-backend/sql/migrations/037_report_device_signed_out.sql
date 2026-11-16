-- A phone is counted from the first time the app opens, before anyone signs
-- up on it, so the admin's Devices page shows installs that never made an
-- account (and how many did).
--
-- report_device() now takes a call without an account too: that install is
-- kept without a user, and gets one when someone signs in on it. A call
-- without an account never takes the user off an install (signing out
-- leaves it counted as registered).
--
-- The API answers only signed-in users (018_api_requires_sign_in.sql); this
-- one call is let through without a token, as `anon`, which may run
-- report_device and nothing else new. It only adds or updates a phone's row:
-- nothing is read back.

create or replace function public.report_device(
  p_device_id   uuid,
  p_platform    text,
  p_app_version text,
  p_build       integer,
  p_os_version  text default null,
  p_model       text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if p_device_id is null or p_platform not in ('ios', 'android')
     or coalesce(p_app_version, '') = '' or p_build is null then
    return;
  end if;
  -- A runaway client can't flood the figures: a new install past the 20th
  -- on one account isn't recorded.
  if me is not null
     and not exists (select 1 from app_devices where device_id = p_device_id)
     and (select count(*) from app_devices where user_id = me) >= 20 then
    return;
  end if;
  insert into app_devices
    (device_id, user_id, platform, app_version, build, os_version, model)
  values
    (p_device_id, me, p_platform, left(p_app_version, 32),
     greatest(0, least(p_build, 999999)),
     nullif(left(p_os_version, 64), ''), nullif(left(p_model, 64), ''))
  on conflict (device_id) do update set
    user_id      = coalesce(excluded.user_id, app_devices.user_id),
    platform     = excluded.platform,
    app_version  = excluded.app_version,
    build        = excluded.build,
    os_version   = excluded.os_version,
    model        = excluded.model,
    last_seen_at = now();
end;
$$;

grant execute on function public.report_device(uuid, text, text, integer, text, text)
  to anon;

create or replace function public.api_require_sign_in()
returns void
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() is not null then
    return;
  end if;
  if current_setting('request.method', true) = 'GET'
     and current_setting('request.path', true) = '/profiles' then
    set local role anon;
    return;
  end if;
  -- An install not signed in yet tells which phone it is (Devices page).
  if current_setting('request.method', true) = 'POST'
     and current_setting('request.path', true) = '/rpc/report_device' then
    set local role anon;
    return;
  end if;
  raise sqlstate 'PT401' using message = 'Sign in required';
end;
$$;

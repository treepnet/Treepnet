-- The phones the app runs on, for the admin panel's Devices page.
--
-- Nothing told the server which phone, app version or OS a user had. From
-- 1.0.9 the app reports it when a signed-in user opens it (at most daily,
-- and again on a new version or account): report_device() keeps one row per
-- install, under a random id the app makes (not a hardware id).
--
-- Older builds don't report. Their platform is still known from the chat
-- service, which keeps each user's last one ("TreepNet ios" / "TreepNet
-- android"): analytics.chat_platform holds a copy, refreshed nightly by
-- ~/analytics-rollup.sh (the chat database is a separate one).
--
-- analytics_ro reads both through analytics.* only.

create table public.app_devices (
  device_id     uuid primary key,
  -- The account last signed in on it. A deleted account leaves the device
  -- counted, without the link.
  user_id       uuid references public.profiles (id) on delete set null,
  platform      text not null check (platform in ('ios', 'android')),
  app_version   text not null check (length(app_version) between 1 and 32),
  build         integer not null check (build between 0 and 999999),
  os_version    text check (length(os_version) <= 64),
  model         text check (length(model) <= 64),
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

create index app_devices_user_id_idx on public.app_devices (user_id);

-- Only report_device() writes it; nobody reads it through the API.
alter table public.app_devices enable row level security;
revoke all on table public.app_devices from public, anon, authenticated;

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
  if me is null or p_device_id is null or p_platform not in ('ios', 'android')
     or coalesce(p_app_version, '') = '' or p_build is null then
    return;
  end if;
  -- A runaway client can't flood the figures: a new install past the 20th
  -- on one account isn't recorded.
  if not exists (select 1 from app_devices where device_id = p_device_id)
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
    user_id      = excluded.user_id,
    platform     = excluded.platform,
    app_version  = excluded.app_version,
    build        = excluded.build,
    os_version   = excluded.os_version,
    model        = excluded.model,
    last_seen_at = now();
end;
$$;

revoke all on function public.report_device(uuid, text, text, integer, text, text)
  from public, anon;
grant execute on function public.report_device(uuid, text, text, integer, text, text)
  to authenticated;

-- Each user's last platform as the chat service knows it (see above).
create table analytics.chat_platform (
  user_id  uuid primary key,
  platform text not null check (platform in ('ios', 'android')),
  seen_at  timestamptz
);

create or replace view analytics.devices as
  select device_id, user_id, platform, app_version, build, os_version, model,
         first_seen_at, last_seen_at
  from public.app_devices;

grant select on table analytics.devices, analytics.chat_platform to analytics_ro;

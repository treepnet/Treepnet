#!/bin/sh
# Nightly DAU/WAU/MAU snapshot for analytics.daily_active (last_seen_at is
# point-in-time, so trends need a daily capture). Installed by the admin-panel
# deploy. Runs as the DB superuser inside the postgres container.
U=$(docker exec treepnet-postgres printenv POSTGRES_USER)
docker exec treepnet-postgres psql -U "$U" -d treepnet -c \
"insert into analytics.daily_active(day,dau,wau,mau,signups) \
 select current_date, dau, wau, mau, \
   (select count(*) from analytics.signups where created_at >= current_date and created_at < current_date + 1) \
 from analytics.active_users \
 on conflict (day) do update set dau=excluded.dau, wau=excluded.wau, mau=excluded.mau, signups=excluded.signups;"
# Presence log retention (analytics.activity, one row per user-minute).
docker exec treepnet-postgres psql -U "$U" -d treepnet -c \
"delete from analytics.activity where minute < now() - interval '400 days';"
# Each user's last platform as the chat service knows it, for the admin
# Devices page (analytics.chat_platform, migration 036): builds before 1.0.9
# report nothing else. The chat database is a separate one, so it is copied
# over; an empty read (chat down) leaves yesterday's copy as it was.
docker exec treepnet-postgres psql -U "$U" -d chat -At -F, -c \
"select \"uuid\", lower(substr(\"deviceName\", 10)), \"updatedAt\" from \"User\" \
 where \"deviceName\" in ('TreepNet ios', 'TreepNet android') \
   and \"uuid\" ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'" \
| docker exec -i treepnet-postgres psql -U "$U" -d treepnet -1 -q -v ON_ERROR_STOP=1 \
  -c "create temp table cp (user_id uuid, platform text, seen_at timestamp)" \
  -c "\copy cp from pstdin with (format csv)" \
  -c "delete from analytics.chat_platform where exists (select 1 from cp)" \
  -c "insert into analytics.chat_platform (user_id, platform, seen_at) \
      select distinct on (user_id) user_id, platform, seen_at at time zone 'UTC' from cp \
      where user_id in (select id from public.profiles) order by user_id, seen_at desc"

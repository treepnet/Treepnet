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

#!/usr/bin/env bash
# TreepNet server watchdog. Cron runs it every 5 minutes:
#   */5 * * * * /home/ubuntu/treepnet-monitor.sh >> /home/ubuntu/treepnet-monitor.log 2>&1
#
# Each check prints a line when something is wrong and nothing when all is
# well. A problem is sent to the private Telegram log chat when it has failed
# two runs in a row (so a blip stays quiet), repeated every 6 hours while it
# lasts, and followed by an "OK again" once it clears. A container restart is
# an event and is sent at once. Telegram is called directly — not through our
# own error logger — so alerts still go out when our services are down. A
# message counts as sent only once Telegram took it: until then it is tried
# again on every run, so one failed send no longer hides a problem for 6 hours.
# (The server being off entirely is caught from outside by the Cloudflare
# uptime worker, oci-backend/uptime-worker.)
set -u

STATE_DIR="$HOME/.treepnet-monitor"
ENV_FILE="$HOME/treepnet/.env"
mkdir -p "$STATE_DIR"

# One run at a time: with Telegram down, retries can make a run outlast the
# 5 minutes, and two runs would count the same failure twice.
exec 9>"$STATE_DIR/lock"
flock -n 9 || exit 0

TOKEN=$(grep -m1 '^TG_LOG_BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
CHAT=$(grep -m1 '^TG_LOG_CHAT_ID=' "$ENV_FILE" | cut -d= -f2-)

# send TEXT — true once Telegram took it: three tries (1 s, then 4 s apart).
# After a send that failed every try, the rest of the run doesn't wait on
# Telegram again; what wasn't sent is tried on the next run.
TG_DOWN=0
send() {
  local try
  [ "$TG_DOWN" = 1 ] && return 1
  for try in 1 2 3; do
    curl -fsS -m 10 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
      --data-urlencode "chat_id=${CHAT}" --data-urlencode "text=$1" >/dev/null 2>&1 && return 0
    case $try in 1) sleep 1 ;; 2) sleep 4 ;; esac
  done
  TG_DOWN=1
  echo "$(date -u +%FT%TZ) telegram send failed; trying again next run"
  return 1
}

sql() {
  docker exec treepnet-postgres sh -c "psql -U \"\$POSTGRES_USER\" -d treepnet -Atc \"$1\"" 2>/dev/null
}

# check NAME COMMAND... — alert after 2 failing runs, every 72 runs (6 h)
# while it lasts, and once when it recovers. An alert Telegram didn't take
# ($name.unsent, $name.recovered) is sent again on the next run.
check() {
  local name=$1
  shift
  local out fails
  out=$("$@" 2>&1)
  fails=$(cat "$STATE_DIR/$name.fails" 2>/dev/null || echo 0)
  if [ -n "$out" ]; then
    rm -f "$STATE_DIR/$name.recovered"
    fails=$((fails + 1))
    echo "$fails" >"$STATE_DIR/$name.fails"
    if [ "$fails" -eq 2 ] || [ $((fails % 72)) -eq 0 ] || [ -f "$STATE_DIR/$name.unsent" ]; then
      if send "🔴 TreepNet server: $out"; then
        rm -f "$STATE_DIR/$name.unsent"
      else
        touch "$STATE_DIR/$name.unsent"
      fi
    fi
    echo "$(date -u +%FT%TZ) $name: $out"
  else
    if [ "$fails" -ge 2 ]; then
      echo "✅ TreepNet server: $name is OK again (failed for about $((fails * 5)) min)" \
        >"$STATE_DIR/$name.recovered"
    fi
    rm -f "$STATE_DIR/$name.fails" "$STATE_DIR/$name.unsent"
    if [ -f "$STATE_DIR/$name.recovered" ] && send "$(cat "$STATE_DIR/$name.recovered")"; then
      rm -f "$STATE_DIR/$name.recovered"
    fi
  fi
}

disk() {
  local pct
  pct=$(df --output=pcent / | tail -1 | tr -dc '0-9')
  [ "$pct" -ge 80 ] && echo "disk / is ${pct}% full"
}

containers() {
  docker ps -a --filter label=com.docker.compose.project=treepnet \
    --format '{{.Names}} {{.State}}' | awk '$2 != "running" { printf "%s is %s; ", $1, $2 }'
}

# Running but failing its healthcheck (stuck, or can't reach what it needs).
health() {
  docker ps --filter label=com.docker.compose.project=treepnet \
    --filter health=unhealthy --format '{{.Names}}' | awk '{ printf "%s is unhealthy; ", $1 }'
}

# Restarts are events: report each new one at once. The count is saved only
# once the report went out, so one Telegram didn't take is sent next run.
restarts() {
  local name count prev
  for name in $(docker ps --filter label=com.docker.compose.project=treepnet --format '{{.Names}}'); do
    count=$(docker inspect -f '{{.RestartCount}}' "$name")
    prev=$(cat "$STATE_DIR/$name.restarts" 2>/dev/null || echo "$count")
    if [ "$count" -gt "$prev" ]; then
      send "🟠 TreepNet server: $name restarted ($((count - prev)) time(s) since the last report)" ||
        continue
    fi
    echo "$count" >"$STATE_DIR/$name.restarts"
  done
}

endpoints() {
  local url code
  for url in \
    'https://api.treepnet.com/profiles?select=id&limit=1' \
    'https://api.treepnet.com/auth/health' \
    'https://api.treepnet.com/delete-account/health' \
    'https://api.treepnet.com/log/health' \
    'https://api.treepnet.com/app-config/version.json' \
    'https://sync.treepnet.com/probes/readiness' \
    'https://chat.treepnet.com/health' \
    'https://treepnet.com/delete-account/'; do
    code=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "$url")
    [ "$code" = "200" ] || printf '%s answered %s; ' "$url" "$code"
  done
}

# PowerSync reads changes through a replication slot: inactive or far behind
# means devices stop getting new data. wal_status 'unreserved' = close to the
# 4GB max_slot_wal_keep_size (sql/wal_slot_limit.sql), 'lost' = past it and
# given up: PowerSync then has to replicate everything again.
replication() {
  local row
  row=$(sql "select slot_name || ' active=' || active || ' wal=' || coalesce(wal_status, '?') || ' lag_mb=' || (pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) / 1048576)::int from pg_replication_slots where slot_name like 'powersync%' and (not active or wal_status in ('unreserved', 'lost') or pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) > 268435456)")
  [ -n "$row" ] && echo "PowerSync replication: $row"
}

# PostgREST checks signed-in requests against a copy of Google's signing keys
# (postgrest/refresh-jwks.sh, hourly). A key Google signs with that the copy
# lacks — or a copy PostgREST never loaded — refuses every signed-in write
# with 401, which the endpoint checks can't see (they call without a token).
# Google publishes a new key a while before signing with it, so a missing key
# is reported only after 90 minutes: the hourly refresh had its chance.
jwks() {
  local file=/home/ubuntu/treepnet/postgrest/jwks.json live missing since now started
  live=$(curl -fsS -m 15 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com') || return 0
  missing=$(printf '%s' "$live" | python3 -c '
import json, sys
live = {k.get("kid") for k in json.load(sys.stdin).get("keys", [])}
try:
    have = {k.get("kid") for k in json.load(open(sys.argv[1])).get("keys", [])}
except Exception:
    have = set()
print(" ".join(sorted(k for k in live - have if k)))' "$file" 2>/dev/null)
  now=$(date +%s)
  if [ -n "$missing" ]; then
    since=$(cat "$STATE_DIR/jwks.missing-since" 2>/dev/null || echo "$now")
    echo "$since" >"$STATE_DIR/jwks.missing-since"
    [ $((now - since)) -ge 5400 ] &&
      echo "PostgREST lacks Google signing key(s) $missing for $(((now - since) / 60)) min: signed-in writes get 401 (see postgrest/refresh-jwks.log)"
  else
    rm -f "$STATE_DIR/jwks.missing-since"
  fi
  started=$(date -d "$(docker inspect -f '{{.State.StartedAt}}' treepnet-postgrest)" +%s 2>/dev/null || echo 0)
  [ "$(stat -c %Y "$file")" -gt $((started + 60)) ] &&
    echo "PostgREST wasn't restarted after jwks.json changed: it still checks tokens with the old keys"
}

push_queue() {
  local row
  row=$(sql "select count(*) || ' unsent, oldest ' || coalesce(extract(epoch from now() - min(created_at))::int / 60, 0) || ' min' from push_outbox where status not in ('sent', 'failed') having count(*) > 200 or min(created_at) < now() - interval '15 minutes'")
  [ -n "$row" ] && echo "push queue stuck: $row"
}

# Pushes that don't go through for a reason other than "no device". A bad
# Apple or Firebase key (THIRD_PARTY_AUTH_ERROR, SENDER_ID_MISMATCH) stops
# every iOS (or every) push and showed nowhere: one is enough. Otherwise 5
# failures in an hour, or under 80 % of 10+ getting through.
push_failures() {
  local row
  row=$(sql "with h as (select status, last_error from push_outbox where created_at > now() - interval '1 hour' and coalesce(last_error, '') <> 'no token'), c as (select count(*) filter (where last_error like '%THIRD_PARTY_AUTH_ERROR%' or last_error like '%SENDER_ID_MISMATCH%') auth, count(*) filter (where status = 'failed') failed, count(*) filter (where status = 'sent') sent from h) select case when auth > 0 then 'push: ' || auth || ' failing on the Apple/Firebase key: ' || (select left(last_error, 120) from h where last_error like '%THIRD_PARTY_AUTH_ERROR%' or last_error like '%SENDER_ID_MISMATCH%' limit 1) else 'push: ' || failed || ' failed, ' || sent || ' sent in the last hour' end from c where auth > 0 or failed >= 5 or (failed + sent >= 10 and sent * 100 < (failed + sent) * 80)")
  [ -n "$row" ] && echo "$row"
}

# PowerSync stops ALL of a connection's sync past max_buckets_per_connection
# (3000, powersync/service.yaml): one bucket per person the user follows, plus
# open profiles and posts. Follows are capped at 2000 (migration 021); this
# says when anyone gets near, from the buckets each checkpoint logs.
sync_buckets() {
  local max
  max=$(docker logs --since 10m treepnet-powersync 2>&1 | grep -o '"buckets":[0-9]*' | cut -d: -f2 | sort -n | tail -1)
  [ -n "$max" ] && [ "$max" -gt 1500 ] && echo "a sync connection has $max buckets (PowerSync stops all its sync past 3000)"
}

# Account deletions finish in the background (functions/delete-account/
# cleanup.js). A job still there after a day is failing, or waiting on
# something like a lost bucket permission (waiting doesn't count as an
# attempt, so attempts alone would never show it).
deletions() {
  local row
  row=$(sql "select count(*) || ' account deletion job(s) unfinished; last error: ' || coalesce(left(max(last_error), 150), '-') from account_deletion_jobs where attempts >= 3 or created_at < now() - interval '1 day' having count(*) > 0")
  [ -n "$row" ] && echo "$row"
}

# Photo files of deleted posts, stories and avatars wait in
# media_deletion_queue for the same worker, which deletes them within a minute.
media_queue() {
  local row
  row=$(sql "select count(*) || ' photo file(s) not deleted from storage; last error: ' || coalesce(left(max(last_error), 150), 'none, but waiting over a day') from media_deletion_queue where attempts >= 3 or queued_at < now() - interval '1 day' having count(*) > 0")
  [ -n "$row" ] && echo "$row"
}

# Certificates renew on their own (Caddy; Cloudflare for treepnet.com): one
# within 14 days of its end means renewal is failing.
certs() {
  local host end left
  for host in api.treepnet.com sync.treepnet.com chat.treepnet.com admin.treepnet.com treepnet.com; do
    end=$(echo | timeout 10 openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null |
      openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$end" ]; then
      printf '%s: no certificate read; ' "$host"
      continue
    fi
    left=$((($(date -d "$end" +%s) - $(date +%s)) / 86400))
    [ "$left" -lt 14 ] && printf '%s certificate ends in %s days; ' "$host" "$left"
  done
}

# The server has no swap, and Postgres takes at most 100 connections.
resources() {
  local total avail conns
  read -r total avail < <(free -m | awk '/^Mem:/ {print $2, $7}')
  [ $((avail * 100 / total)) -lt 10 ] && printf 'memory low: %s of %s MB available; ' "$avail" "$total"
  conns=$(sql "select count(*) from pg_stat_activity")
  [ "${conns:-0}" -gt 80 ] && printf 'postgres has %s connections (max 100); ' "$conns"
}

# Scheduled jobs that have no log of their own send their errors to
# cron-errors.log (crontab.txt); one written to in the last 10 minutes is a
# job failing now.
cron_errors() {
  local log="$HOME/cron-errors.log"
  [ -s "$log" ] && [ -n "$(find "$log" -mmin -10)" ] &&
    echo "a scheduled job is failing: $(tail -1 "$log" | cut -c1-200)"
}

# The nightly backup and the weekly restore check only write to backup.log,
# and a failed run just stops there. A good backup is due every night
# (22:30 UTC) and an ok check every Sunday (23:30 UTC); allow some slack.
backups() {
  local log="$HOME/backup.log" now last age check
  now=$(date +%s)
  last=$(grep ' backup: ok ' "$log" 2>/dev/null | tail -1 | cut -d' ' -f1)
  if [ -z "$last" ]; then
    echo "no successful backup in backup.log"
    return
  fi
  age=$(((now - $(date -d "$last" +%s)) / 3600))
  [ "$age" -ge 26 ] && echo "last good backup was ${age} h ago"
  check=$(grep ' check: ' "$log" 2>/dev/null | tail -1)
  case "$check" in
  *' check: FAILED'*) echo "restore check failed:${check#* check: FAILED:}" ;;
  *' check: ok'*)
    age=$(((now - $(date -d "${check%% *}" +%s)) / 3600))
    [ "$age" -ge 200 ] && echo "last restore check was ${age} h ago"
    ;;
  esac
}

if [ ! -f "$STATE_DIR/installed" ]; then
  send "✅ TreepNet server monitor is on (checks every 5 min)" && touch "$STATE_DIR/installed"
fi

check disk disk
check containers containers
check health health
restarts
check endpoints endpoints
check replication replication
check sync_buckets sync_buckets
check jwks jwks
check push_queue push_queue
check push_failures push_failures
check deletions deletions
check media_queue media_queue
check backups backups
check cron_errors cron_errors
check certs certs
check resources resources

# Proof of life for the uptime worker outside (oci-backend/uptime-worker): it
# reads this time and reports when the monitor stops running, which nothing
# here can.
date -u +%s >"$HOME/treepnet/caddy/web/app-config/heartbeat.txt" 2>/dev/null ||
  echo "$(date -u +%FT%TZ) heartbeat write failed"

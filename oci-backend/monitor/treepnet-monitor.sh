#!/usr/bin/env bash
# TreepNet server watchdog. Cron runs it every 5 minutes:
#   */5 * * * * /home/ubuntu/treepnet-monitor.sh >> /home/ubuntu/treepnet-monitor.log 2>&1
#
# Each check prints a line when something is wrong and nothing when all is
# well. A problem is sent to the private Telegram log chat when it has failed
# two runs in a row (so a blip stays quiet), repeated every 6 hours while it
# lasts, and followed by an "OK again" once it clears. A container restart is
# an event and is sent at once. Telegram is called directly — not through our
# own error logger — so alerts still go out when our services are down.
# (The server being off entirely is caught from outside by the Cloudflare
# uptime worker, oci-backend/uptime-worker.)
set -u

STATE_DIR="$HOME/.treepnet-monitor"
ENV_FILE="$HOME/treepnet/.env"
mkdir -p "$STATE_DIR"

TOKEN=$(grep -m1 '^TG_LOG_BOT_TOKEN=' "$ENV_FILE" | cut -d= -f2-)
CHAT=$(grep -m1 '^TG_LOG_CHAT_ID=' "$ENV_FILE" | cut -d= -f2-)

send() {
  curl -fsS -m 15 -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT}" --data-urlencode "text=$1" >/dev/null ||
    echo "$(date -u +%FT%TZ) telegram send failed"
}

sql() {
  docker exec treepnet-postgres sh -c "psql -U \"\$POSTGRES_USER\" -d treepnet -Atc \"$1\"" 2>/dev/null
}

# check NAME COMMAND... — alert after 2 failing runs, every 72 runs (6 h)
# while it lasts, and once when it recovers.
check() {
  local name=$1
  shift
  local out fails
  out=$("$@" 2>&1)
  fails=$(cat "$STATE_DIR/$name.fails" 2>/dev/null || echo 0)
  if [ -n "$out" ]; then
    fails=$((fails + 1))
    echo "$fails" >"$STATE_DIR/$name.fails"
    if [ "$fails" -eq 2 ] || [ $((fails % 72)) -eq 0 ]; then
      send "🔴 TreepNet server: $out"
    fi
    echo "$(date -u +%FT%TZ) $name: $out"
  else
    if [ "$fails" -ge 2 ]; then send "✅ TreepNet server: $name is OK again"; fi
    rm -f "$STATE_DIR/$name.fails"
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

# Restarts are events: report each new one at once.
restarts() {
  local name count prev
  for name in $(docker ps --filter label=com.docker.compose.project=treepnet --format '{{.Names}}'); do
    count=$(docker inspect -f '{{.RestartCount}}' "$name")
    prev=$(cat "$STATE_DIR/$name.restarts" 2>/dev/null || echo "$count")
    if [ "$count" -gt "$prev" ]; then
      send "🟠 TreepNet server: $name restarted ($((count - prev)) time(s) in the last 5 min)"
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
    'https://sync.treepnet.com/probes/readiness' \
    'https://chat.130-61-138-104.sslip.io/health'; do
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

deletions() {
  local n
  n=$(sql "select count(*) from account_deletion_jobs where attempts >= 3")
  [ "${n:-0}" -gt 0 ] && echo "$n account deletion job(s) keep failing"
}

if [ ! -f "$STATE_DIR/installed" ]; then
  send "✅ TreepNet server monitor is on (checks every 5 min)"
  touch "$STATE_DIR/installed"
fi

check disk disk
check containers containers
check health health
restarts
check endpoints endpoints
check replication replication
check jwks jwks
check push_queue push_queue
check deletions deletions

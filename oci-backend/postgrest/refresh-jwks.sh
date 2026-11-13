#!/usr/bin/env bash
# Keep PostgREST's Firebase JWKS fresh.
#
# Firebase (securetoken) rotates its RS256 signing keys every few days. PostgREST
# verifies uploaded writes against a STATIC jwks.json; once it lacks the key
# that signed a valid token it rejects it with PGRST301 ("No suitable key was
# found to decode the JWT"), which silently breaks every client's PowerSync
# upload. Runs hourly (crontab.txt).
#
# The file holds every key Google has published in the last 24 hours, not just
# what one fetch returned: during a rotation Google's answer alternated between
# 4 and 2 keys, the file followed it, and each swap restarted PostgREST (10
# times on 2026-10-23..26), with a token signed by a key left out refused
# until the next run. A key goes only once it has been absent for KEEP_SECONDS.
#
# A change is loaded with SIGUSR2 (PostgREST re-reads its config and the
# @file secret: "Config reloaded"), not a restart, which dropped requests
# with 502. If that line doesn't show, it falls back to a restart. Either way
# jwks.json.loaded is touched (the monitor compares it with jwks.json).
#
# URL, DEST, STATE, LOG, CONTAINER and KEEP_SECONDS can be overridden (tests).
set -uo pipefail

URL=${URL:-"https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"}
DEST=${DEST:-/home/ubuntu/treepnet/postgrest/jwks.json}
STATE=${STATE:-$DEST.seen.json}
LOG=${LOG:-/home/ubuntu/treepnet/postgrest/refresh-jwks.log}
CONTAINER=${CONTAINER:-treepnet-postgrest}
KEEP_SECONDS=${KEEP_SECONDS:-86400}
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
ts() { date -Is; }

# Never touch a working file with a failed download.
if ! curl -fsS --max-time 20 "$URL" -o "$TMP"; then
  echo "$(ts) fetch failed - keeping current jwks" >>"$LOG"; exit 0
fi

# Merge: what Google publishes now, plus what it published in the last
# KEEP_SECONDS. Writes DEST in place (it is bind-mounted as a single file, so
# it must stay the same file) only when the set of key ids changes. Prints
# "unchanged", "changed <kids>" or "invalid".
result=$(python3 - "$TMP" "$DEST" "$STATE" "$KEEP_SECONDS" <<'PY'
import json, os, sys, time
fetched_path, dest, state_path, keep = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
now = int(time.time())
try:
    fetched = json.load(open(fetched_path)).get('keys')
    assert isinstance(fetched, list) and fetched and all(k.get('kid') for k in fetched)
except Exception:
    print('invalid'); sys.exit(0)
try:
    current = json.load(open(dest)).get('keys', [])
except Exception:
    current = []
try:
    seen = json.load(open(state_path))
except Exception:
    # First run: the keys already in the file count as seen now.
    seen = {k['kid']: {'key': k, 'last_seen': now} for k in current if k.get('kid')}
for k in fetched:
    seen[k['kid']] = {'key': k, 'last_seen': now}
seen = {kid: v for kid, v in seen.items() if now - v['last_seen'] < keep}
fetched_kids = [k['kid'] for k in fetched]
keys = [seen[kid]['key'] for kid in fetched_kids] + [
    v['key'] for kid, v in sorted(seen.items()) if kid not in fetched_kids]
tmp_state = state_path + '.tmp'
json.dump(seen, open(tmp_state, 'w'))
os.replace(tmp_state, state_path)
if sorted(k.get('kid') for k in current) == sorted(k['kid'] for k in keys):
    print('unchanged'); sys.exit(0)
with open(dest, 'w') as f:
    json.dump({'keys': keys}, f)
print('changed ' + ' '.join(sorted(k['kid'] for k in keys)))
PY
)

case "$result" in
  invalid) echo "$(ts) invalid JWKS payload - keeping current jwks" >>"$LOG"; exit 0 ;;
  unchanged) echo "$(ts) jwks unchanged (same kids)" >>"$LOG"; exit 0 ;;
esac

# Changed: load it.
since=$(date -u +%FT%TZ)
if docker kill -s SIGUSR2 "$CONTAINER" >/dev/null 2>&1; then
  for _ in $(seq 10); do
    sleep 1
    if docker logs --since "$since" "$CONTAINER" 2>&1 | grep -q 'Config reloaded'; then
      touch "$DEST.loaded"
      echo "$(ts) jwks now: ${result#changed } + postgrest reloaded" >>"$LOG"
      exit 0
    fi
  done
fi
if docker restart "$CONTAINER" >/dev/null 2>&1; then
  touch "$DEST.loaded"
  echo "$(ts) jwks now: ${result#changed } + postgrest restarted (reload not confirmed)" >>"$LOG"
else
  echo "$(ts) jwks now: ${result#changed } but postgrest reload and restart FAILED" >>"$LOG"
fi

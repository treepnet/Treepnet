#!/usr/bin/env bash
# Keep PostgREST's Firebase JWKS fresh.
#
# Firebase (securetoken) rotates its RS256 signing keys every few days. PostgREST
# verifies uploaded writes against a STATIC jwks.json; once it goes stale it can
# no longer find the key that signed a valid token and rejects it with
# PGRST301 ("No suitable key was found to decode the JWT"), which silently breaks
# every client's PowerSync upload. This script refetches Google's live JWKS and
# reloads PostgREST whenever the keys change. Safe to run on a schedule.
set -uo pipefail

URL="https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
DEST="/home/ubuntu/treepnet/postgrest/jwks.json"
LOG="/home/ubuntu/treepnet/postgrest/refresh-jwks.log"
TMP="$(mktemp)"
ts() { date -Is; }

# Never clobber a working file with a failed download.
if ! curl -fsS --max-time 20 "$URL" -o "$TMP"; then
  echo "$(ts) fetch failed - keeping current jwks" >>"$LOG"; rm -f "$TMP"; exit 0
fi

# Must be valid JSON with a non-empty keys array.
if ! python3 -c "import json,sys; d=json.load(open('$TMP')); sys.exit(0 if isinstance(d.get('keys'),list) and d['keys'] else 1)" 2>/dev/null; then
  echo "$(ts) invalid JWKS payload - keeping current jwks" >>"$LOG"; rm -f "$TMP"; exit 0
fi

# Compare by the SET of key ids, not raw bytes: Google may return the same keys
# in a different order or formatting between requests, and only an actual key
# rotation should trigger a reload.
kids() { python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(' '.join(sorted(k.get('kid','') for k in d.get('keys',[]))))" "$1" 2>/dev/null; }
if [ -n "$(kids "$DEST")" ] && [ "$(kids "$TMP")" = "$(kids "$DEST")" ]; then
  echo "$(ts) jwks unchanged (same kids)" >>"$LOG"; rm -f "$TMP"; exit 0
fi

# Changed: keep a one-step rollback, swap in, reload PostgREST.
cp "$DEST" "$DEST.prev" 2>/dev/null || true
cp "$TMP" "$DEST"; rm -f "$TMP"
if docker restart treepnet-postgrest >/dev/null 2>&1; then
  echo "$(ts) jwks updated + postgrest restarted" >>"$LOG"
else
  echo "$(ts) jwks updated but postgrest restart FAILED" >>"$LOG"
fi

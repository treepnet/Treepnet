#!/usr/bin/env bash
# Weekly proof that the newest backup can actually be restored (fix list P0 #2).
#
# Decrypts the newest archive in ~/backups, restores both databases into
# scratch databases, compares their tables and row counts with the live ones,
# then drops the scratch databases. Logs "ok" or "FAILED: ...".
# A backup is a few hours old when this runs, so row counts may differ a
# little; it fails only on a missing table or an empty restore.
#
# Cron (ubuntu, Sundays, an hour after the nightly backup):
#   30 23 * * 0 /home/ubuntu/treepnet-backup-check.sh >> /home/ubuntu/backup.log 2>&1
set -euo pipefail
umask 077

pass_file=/home/ubuntu/.backup-passphrase
latest=$(ls -1t /home/ubuntu/backups/treepnet-*.tar.enc | head -1)
pg_user=$(sudo docker exec treepnet-postgres printenv POSTGRES_USER)
work=$(mktemp -d)

log() { echo "$(date -u +%FT%TZ) check: $*"; }
sql() {
  sudo docker exec -i -e PGOPTIONS=--client-min-messages=warning treepnet-postgres \
    psql -U "$pg_user" -v ON_ERROR_STOP=1 -qAt "$@"
}
cleanup() {
  rm -rf "$work"
  for db in treepnet chat; do
    sql -d postgres -c "drop database if exists restore_check_$db" || true
  done
}
trap cleanup EXIT

# Tables and total rows in the public schema of database $1.
stats() {
  sql -d "$1" <<'SQL'
select count(*) || ' ' || coalesce(sum((xpath('/row/c/text()', query_to_xml(
         format('select count(*) as c from %I.%I', table_schema, table_name),
         false, true, '')))[1]::text::bigint), 0)
from information_schema.tables
where table_schema = 'public' and table_type = 'BASE TABLE';
SQL
}

openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass "file:$pass_file" -in "$latest" |
  tar -C "$work" -xf -

failed=""
report=""
for db in treepnet chat; do
  scratch="restore_check_$db"
  sql -d postgres -c "drop database if exists $scratch" -c "create database $scratch"
  # Ownership and grants refer to roles; the check only needs the data.
  sudo docker exec -i treepnet-postgres pg_restore -U "$pg_user" -d "$scratch" \
    --no-owner --no-privileges <"$work/$db.dump" 2>"$work/$db.restore.log" || true
  read -r live_tables live_rows <<<"$(stats "$db")"
  read -r got_tables got_rows <<<"$(stats "$scratch")"
  report+=" $db: tables $got_tables/$live_tables rows $got_rows/$live_rows;"
  if [ "$got_tables" != "$live_tables" ] || [ "$got_rows" = 0 ]; then
    failed+=" $db"
  fi
done

if [ -n "$failed" ]; then
  log "FAILED:$failed —$report ($(basename "$latest"))"
  exit 1
fi
log "ok$report ($(basename "$latest"))"

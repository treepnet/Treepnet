#!/usr/bin/env bash
# Weekly proof that the newest backup can actually be restored (fix list P0 #2).
#
# Decrypts the newest archive in ~/backups, restores both databases into
# scratch databases with their owners and grants, compares them with the live
# ones, then drops the scratch databases. Logs "ok" or "FAILED: ...".
# Compared: tables, RLS policies, functions, triggers and the API roles'
# grants must match; rows must be there (a backup is an hour old when this
# runs, so the counts may differ a little). It used to restore without grants,
# hide pg_restore's errors and compare tables and rows only, so a restore
# missing its policies or grants still said ok.
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

# Database $1's public schema: tables, total rows, RLS policies, functions,
# triggers, and table grants to the API roles.
stats() {
  sql -d "$1" <<'SQL'
select (select count(*) from information_schema.tables
         where table_schema = 'public' and table_type = 'BASE TABLE')
  || ' ' || (select coalesce(sum((xpath('/row/c/text()', query_to_xml(
         format('select count(*) as c from %I.%I', table_schema, table_name),
         false, true, '')))[1]::text::bigint), 0)
       from information_schema.tables
      where table_schema = 'public' and table_type = 'BASE TABLE')
  || ' ' || (select count(*) from pg_policies where schemaname = 'public')
  || ' ' || (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public')
  || ' ' || (select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid
              join pg_namespace n on n.oid = c.relnamespace
             where n.nspname = 'public' and not t.tgisinternal)
  || ' ' || (select count(*) from information_schema.role_table_grants
              where table_schema = 'public' and grantee in ('anon', 'authenticated'));
SQL
}

openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -pass "file:$pass_file" -in "$latest" |
  tar -C "$work" -xf -

failed=""
report=""
for db in treepnet chat; do
  scratch="restore_check_$db"
  sql -d postgres -c "drop database if exists $scratch" -c "create database $scratch"
  # With owners and grants: the roles are on this server, and a restore
  # that loses its grants or policies is not one to rely on.
  errors=0
  sudo docker exec -i treepnet-postgres pg_restore -U "$pg_user" -d "$scratch" \
    <"$work/$db.dump" 2>"$work/$db.restore.log" ||
    errors=$(grep -c '^pg_restore: error' "$work/$db.restore.log" || true)
  read -r lt lr lp lf ltr lg <<<"$(stats "$db")"
  read -r gt gr gp gf gtr gg <<<"$(stats "$scratch")"
  report+=" $db: tables $gt/$lt rows $gr/$lr policies $gp/$lp functions $gf/$lf"
  report+=" triggers $gtr/$ltr grants $gg/$lg restore errors $errors;"
  if [ "$gt" != "$lt" ] || [ "$gr" = 0 ] || [ "$gp" != "$lp" ] || [ "$gf" != "$lf" ] ||
    [ "$gtr" != "$ltr" ] || [ "$gg" != "$lg" ] || [ "$errors" != 0 ]; then
    failed+=" $db"
  fi
done

if [ -n "$failed" ]; then
  log "FAILED:$failed —$report ($(basename "$latest"))"
  exit 1
fi
log "ok$report ($(basename "$latest"))"

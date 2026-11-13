#!/usr/bin/env bash
# Applies the numbered files in migrations/ that the treepnet database hasn't
# had yet, in name order, each in its own transaction together with its row
# in public.schema_migrations — so the database itself says which changes it
# has. Run it on the server, from ~/treepnet/sql:
#
#   ./migrate.sh                    apply what is new
#   ./migrate.sh --dry-run          run what is new, all in one transaction,
#                                   then roll it all back (so a file may use
#                                   what an earlier pending one makes)
#   ./migrate.sh --status           list what is applied and what is pending
#   ./migrate.sh --mark-applied F   record F as applied without running it
#                                   (000_baseline.sql on production: it IS
#                                   the schema there)
#
# Writing one: migrations/NNN_what_it_does.sql, the next number, no BEGIN /
# COMMIT of its own (this wraps it). Once applied, a file is never edited —
# a changed one stops the run; fix things in a new file instead. PostgREST
# reloads its schema by itself after it (001_postgrest_auto_reload.sql).
#
# What can't run inside a transaction (CREATE INDEX CONCURRENTLY on a big
# table, ALTER SYSTEM): put `-- migrate: no-transaction` on a line of its own.
# Such a file runs statement by statement and is recorded once it got
# through; one that fails half way is not recorded, so write it to be safe to
# run again (IF NOT EXISTS). --dry-run can't roll it back, so it skips it.
#
# Changes written but not to be applied yet wait in migrations-pending/.
#
# PG_CONTAINER, PG_DB and PG_USER override the defaults below.
set -euo pipefail

container=${PG_CONTAINER:-treepnet-postgres}
db=${PG_DB:-treepnet}
user=${PG_USER:-treepnet}
dir="$(cd "$(dirname "$0")" && pwd)/migrations"

run_psql() {
  docker exec -i "$container" psql -U "$user" -d "$db" -X -q -v ON_ERROR_STOP=1 "$@"
}

checksum() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Only this script and the database owner read or write it.
run_psql <<'SQL'
set client_min_messages = warning;
create table if not exists public.schema_migrations (
  version text primary key,
  checksum text not null,
  applied_at timestamptz not null default now()
);
revoke all on public.schema_migrations from public, anon, authenticated;
SQL

applied_checksum() {
  run_psql -At -c "select checksum from public.schema_migrations where version = '$1'"
}

mode=apply
case "${1:-}" in
  --dry-run) mode=dry ;;
  --status) mode=status ;;
  --mark-applied)
    file="$dir/$(basename "${2:?--mark-applied needs a file name}")"
    [ -f "$file" ] || { echo "no such migration: $file" >&2; exit 1; }
    version=$(basename "$file" .sql)
    run_psql -c "insert into public.schema_migrations (version, checksum)
                 values ('$version', '$(checksum "$file")')
                 on conflict (version) do nothing"
    echo "recorded $version"
    exit 0
    ;;
  "") ;;
  *) echo "unknown option: $1" >&2; exit 1 ;;
esac

pending=()
for file in "$dir"/[0-9][0-9][0-9]_*.sql; do
  version=$(basename "$file" .sql)
  [[ "$version" =~ ^[0-9]{3}_[a-z0-9_]+$ ]] || {
    echo "bad name (want NNN_lower_case.sql): $file" >&2; exit 1; }
  sum=$(checksum "$file")
  recorded=$(applied_checksum "$version")
  if [ -n "$recorded" ]; then
    if [ "$recorded" != "$sum" ]; then
      echo "$version was applied and has changed since — write a new migration instead" >&2
      exit 1
    fi
    [ "$mode" = status ] && echo "applied  $version"
    continue
  fi
  # (`end;` closes PL/pgSQL blocks, so only these three.)
  if grep -qiE '^[[:space:]]*(begin|commit|rollback)[[:space:]]*;' "$file"; then
    echo "$version has its own BEGIN/COMMIT; migrate.sh wraps each file itself" >&2
    exit 1
  fi
  pending+=("$file")
  [ "$mode" = status ] && echo "pending  $version"
done

[ "$mode" = status ] && exit 0
[ ${#pending[@]} -eq 0 ] && { echo "nothing to apply"; exit 0; }

no_transaction() {
  grep -qiE '^--[[:space:]]*migrate:[[:space:]]*no-transaction[[:space:]]*$' "$1"
}

record() {
  echo "insert into public.schema_migrations (version, checksum) values ('$1', '$(checksum "$2")');"
}

if [ "$mode" = dry ]; then
  # All of them in one transaction, in order, then rolled back.
  {
    echo 'begin;'
    for file in "${pending[@]}"; do
      no_transaction "$file" && continue
      version=$(basename "$file" .sql)
      cat "$file"
      echo
      record "$version" "$file"
    done
    echo 'rollback;'
  } | run_psql
  for file in "${pending[@]}"; do
    version=$(basename "$file" .sql)
    if no_transaction "$file"; then
      echo "skipped $version (no-transaction: can't be rolled back)"
    else
      echo "ran and rolled back $version"
    fi
  done
  exit 0
fi

for file in "${pending[@]}"; do
  version=$(basename "$file" .sql)
  if no_transaction "$file"; then
    run_psql < "$file"
    record "$version" "$file" | run_psql
  else
    {
      echo 'begin;'
      cat "$file"
      echo
      record "$version" "$file"
      echo 'commit;'
    } | run_psql
  fi
  echo "applied $version"
done

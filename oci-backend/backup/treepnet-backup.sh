#!/usr/bin/env bash
# Nightly TreepNet backup (fix list P0 #2).
#
# Dumps both databases (and the roles), the chat uploads volume and the server
# config folder (docker-compose, Caddyfile, .env, SQL, functions), packs them
# into one archive, encrypts it (AES-256, passphrase in ~/.backup-passphrase)
# and uploads it to the private OCI bucket `treepnet-backups` through a
# write-only pre-authenticated request (~/.backup-par-url). This server can add
# backups but can neither list, read nor delete them. The last 7 nights also
# stay in ~/backups.
#
# The bucket keeps each archive 30 days without letting anyone (this upload
# link included) delete or overwrite it (retention rule keep-30-days, not
# locked), and deletes it after 35 (lifecycle delete-after-35-days): a deleted
# account's data is gone from the backups within 35 days, as the privacy
# policy says. Anything else left in ~/backups (one-off copies taken before a
# change, kept encrypted) goes after 30 days.
#
# Restoring: see README.md here; treepnet-backup-check.sh does it weekly into
# scratch databases to prove the archives are good.
#
# Cron (ubuntu, server clock is UTC — 03:30 in Tashkent):
#   30 22 * * * /home/ubuntu/treepnet-backup.sh >> /home/ubuntu/backup.log 2>&1
set -euo pipefail
umask 077

backups=/home/ubuntu/backups
keep_days=7
keep_other_days=30
pass_file=/home/ubuntu/.backup-passphrase
par_url=$(cat /home/ubuntu/.backup-par-url) # ends in /o/
ts=$(date -u +%Y%m%d-%H%M%S)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

log() { echo "$(date -u +%FT%TZ) backup: $*"; }

pg_user=$(sudo docker exec treepnet-postgres printenv POSTGRES_USER)
for db in treepnet chat; do
  sudo docker exec treepnet-postgres pg_dump -U "$pg_user" -Fc "$db" >"$work/$db.dump"
done
# Roles with their password hashes, so a restore needs no manual role setup.
sudo docker exec treepnet-postgres pg_dumpall -U "$pg_user" --globals-only >"$work/globals.sql"
# Some of these files are root's; tar runs as root but writes through our
# redirect, so the archive parts stay readable by this script.
sudo tar -C /var/lib/docker/volumes/treepnet_chat_uploads/_data -czf - . >"$work/chat_uploads.tar.gz"
# Not *.dump: a database copy left in the folder (the 2026-08 migration
# dump was) would ride along in every archive, deleted accounts included.
sudo tar -C /home/ubuntu --exclude='*.dump' -czf - treepnet >"$work/server-config.tar.gz"

archive="$backups/treepnet-$ts.tar.enc"
tar -C "$work" -cf - . |
  openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -pass "file:$pass_file" -out "$archive"

curl -fsS --retry 3 --retry-delay 10 -X PUT --data-binary "@$archive" \
  "${par_url}${ts:0:8}/treepnet-$ts.tar.enc"

find "$backups" -maxdepth 1 -name 'treepnet-*.tar.enc' -mtime +"$keep_days" -delete
find "$backups" -maxdepth 1 -type f ! -name 'treepnet-*.tar.enc' \
  -mtime +"$keep_other_days" -delete
log "ok $(basename "$archive") $(du -h "$archive" | cut -f1)"

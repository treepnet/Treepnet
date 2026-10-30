# Backups

Every night at 22:30 UTC (03:30 Tashkent) `treepnet-backup.sh` on the server
takes one encrypted archive and uploads it to the private OCI bucket
`treepnet-backups` (namespace `fryarohmp0gm`, eu-frankfurt-1). The last 7
nights also stay on the server in `~/backups`. On Sundays at 23:30 UTC
`treepnet-backup-check.sh` restores the newest one into scratch databases and
logs `ok` or `FAILED` to `~/backup.log`.

An archive `treepnet-<UTC timestamp>.tar.enc` holds:

| File | What |
|---|---|
| `treepnet.dump` | main database (`pg_dump -Fc`) |
| `chat.dump` | chat database (`pg_dump -Fc`) |
| `globals.sql` | roles with their password hashes |
| `chat_uploads.tar.gz` | chat uploads volume |
| `server-config.tar.gz` | `~/treepnet`: docker-compose, `.env`, Caddyfile, SQL, functions |

`powersync_storage` is not backed up: PowerSync rebuilds it from the main
database.

## Secrets

- `~/.backup-passphrase` (server) — the encryption passphrase. A copy is on
  the owner's Mac in `~/.treepnet-backup-passphrase`; keep one in a password
  manager too. Without it the archives can't be opened.
- `~/.backup-par-url` (server) — a write-only pre-authenticated request for the
  bucket (`server-nightly-backup-write`, expires 2030-01-01). It can upload
  but not list, read or delete. Renew it before it expires.

## Restoring

1. Download an archive (OCI console → Buckets → `treepnet-backups`, or
   `oci os object get --namespace fryarohmp0gm --bucket-name treepnet-backups --name <name> --file backup.tar.enc`).
2. Decrypt and unpack:

   ```bash
   openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
     -pass file:$HOME/.treepnet-backup-passphrase -in backup.tar.enc | tar -xf -
   ```

3. On a fresh server: unpack `server-config.tar.gz` into `~`, start only the
   `postgres` service, then:

   ```bash
   docker exec -i treepnet-postgres psql -U <super> -d postgres < globals.sql
   docker exec -i treepnet-postgres pg_restore -U <super> -d treepnet --clean --if-exists < treepnet.dump
   docker exec -i treepnet-postgres pg_restore -U <super> -d chat --clean --if-exists < chat.dump
   ```

   then unpack `chat_uploads.tar.gz` into the `treepnet_chat_uploads` volume
   and start the rest. PowerSync re-snapshots on its own (see the PowerSync
   notes on BYPASSRLS before checking bucket counts).

## Retention

The bucket has no 30-day expiry rule yet: OCI needs an IAM policy for it, which
was not created. Each night is ~0.5 MB, so this is not urgent. To add it later,
create the policy

    Allow service objectstorage-eu-frankfurt-1 to manage object-family in tenancy where target.bucket.name = 'treepnet-backups'

and then a lifecycle rule on the bucket that deletes objects after 30 days.

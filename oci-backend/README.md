# TreepNet backend — OCI self-hosted stack

The self-hosted backend that replaced the Azure services, running via Docker
Compose on the OCI Ampere ARM (Always-Free) VM. This is a single `docker
compose up` stack; it supersedes the Azure-era `treepnet-push-func/` and
`treepnet-delete-account-func/` folders at the repo root (kept only for
reference).

Every app version talks to this stack; the Azure services are gone.

## Services (`docker-compose.yml`)

| Service | Image / build | Role |
|---|---|---|
| `caddy` | `caddy:2` | TLS (Let's Encrypt) + reverse proxy for the domains below |
| `postgres` | `postgres:16` | App database (`wal_level=logical` for PowerSync) |
| `powersync` | `journeyapps/powersync-service` | Sync service (reads → app) |
| `postgrest` | `postgrest/postgrest` | REST API (writes + RPCs), Firebase ID tokens checked against Google's JWKS |
| `authservice` | `functions/auth-service` | Sign-up, login, password reset (email codes), Firebase custom tokens, photo upload links |
| `pushworker` | `functions/push-worker` | Polls `push_outbox`, sends FCM v1 pushes |
| `deleteaccount` | `functions/delete-account` | Web "delete account" flow (email code + delete), and the clean-up after every account deletion |
| `chatbackend` | `./chatbackend` (from `chatbackend-src/`) | Direct messages: Node + Socket.IO + Prisma, its own `chat` database |
| `errorlogger` | `functions/error-logger` | Forwards app crash/error reports to the private Telegram bot |
| `analyticsapi` | `functions/analytics-api` | Read-only numbers for the admin panel (`analytics_ro` role) |

Public endpoints (Caddy): `https://sync.treepnet.com` → powersync,
`https://api.treepnet.com` → postgrest, `https://api.treepnet.com/auth/*` →
authservice, `https://api.treepnet.com/delete-account/*` → deleteaccount,
`https://api.treepnet.com/log/error` → errorlogger,
`https://api.treepnet.com/app-config/*` → the force-update file,
`https://chat.treepnet.com` → chatbackend, `https://admin.treepnet.com` → the
admin panel and analyticsapi. Auth is Firebase: authservice mints custom
tokens, and PowerSync, PostgREST and chat check the Firebase ID token.

The `errorlogger` needs three env vars in `.env` (`TG_LOG_BOT_TOKEN`,
`TG_LOG_CHAT_ID`, `LOG_APP_KEY`). It has no database or secret-file dependency,
so deploying it is just: `docker compose up -d --build errorlogger` and then
reload Caddy for the new `/log/*` route
(`docker exec treepnet-caddy caddy reload --config /etc/caddy/Caddyfile`).

## Deploy

1. **Secrets (not in git — see `.gitignore`):**
   - `cp .env.example .env` and fill in real values.
   - Put the Firebase service-account JSON at `functions/fcm-service-account.json`.
   - Fetch Google's JWKS for PostgREST with `postgrest/refresh-jwks.sh`; the
     hourly cron keeps it fresh (Firebase rotates its keys every few days).
2. **Bring it up:**
   ```bash
   docker compose up -d --build
   ```
   On first run, `postgres/initdb/01-powersync.sh` creates the PowerSync
   replication role + `powersync` publication. Create the `chat` and
   `powersync_storage` (owner powersync) databases, and apply the server
   settings in `postgres/cluster-settings.sql` (then restart postgres). Then
   the schema: create the
   roles (`sql/setup-roles.sql`: roles only, no privileges, then set the
   analytics_ro / chat_blocks_ro passwords from `.env`), run `sql/migrate.sh`
   (it builds everything, privileges included, from
   `sql/migrations/000_baseline.sql` on), and restore the app data into the
   `treepnet` database (the data dump is not kept in git).
3. **Verify:** the `sql/` helpers (`check-auth.sql`, `check-push.sql`,
   `verify.sql`, …) are diagnostic queries; `sql/setup-roles.sql` documents the
   `authenticator`/`authenticated` role setup PostgREST relies on.

## Monthly maintenance (OS updates and reboot)

Unattended upgrades install Ubuntu security fixes but never reboot, and
Docker's own packages aren't covered: a new kernel or libc only runs after a
reboot (`/var/run/reboot-required`). Once a month, at a quiet hour (all
services are down for about a minute):

1. Back up the boot volume (OCI console → the instance → Boot volume →
   Create backup; free tier keeps up to 5).
2. `sudo apt-get update && sudo apt-get full-upgrade` (keep existing config
   files when asked).
3. `sudo reboot`, then check: `docker ps` (all 10 healthy), the public URLs,
   and the PowerSync slot (`pg_replication_slots`, active, small lag).

`/etc/iptables/rules.v4` and `rules.v6` must hold only the server's own rules
(SSH, 80/443, Oracle's InstanceServices): Docker adds its rules each time it
starts. Never `netfilter-persistent save` while Docker runs — that stores
Docker's rules with the current container addresses, and after a later
reboot they point at the wrong containers (it happened: the August file sent
127.0.0.1:5432 to PowerSync's address). Last done: 2026-11-13 (kernel
7.0.0-1016, Docker 29.9.3; backup `before-reboot-2026-11-13`).

## Database changes

`sql/migrations/` is the treepnet database's history: `000_baseline.sql` is
the whole schema as of 2026-11-01, and each change after it is the next
numbered file (`002_what_it_does.sql`, …), without its own BEGIN/COMMIT. Copy
the folder and `sql/migrate.sh` to `~/treepnet/sql/` and run
`./migrate.sh --dry-run`, then `./migrate.sh`: it applies what is new, in
order, each file in one transaction with its row in `schema_migrations`, and
refuses to go on if an applied file was edited. `./migrate.sh --status` lists
both. PostgREST reloads its schema by itself after any change
(`001_postgrest_auto_reload.sql`); no `notify pgrst` needed.
`sql/migrations-pending/` holds changes written but waiting on something (each
says what); move one into `migrations/` with the next number when it is due.

The other files in `sql/` are what was applied by hand before (each with its
own notes and rollback) and diagnostic queries; they are history, already in
the baseline. The chat database has its own migrations (Prisma, in
`chatbackend-src/prisma/`).

## Scheduled jobs (ubuntu's crontab on the server)

`crontab.txt` is the crontab, verbatim — install it with
`crontab oci-backend/crontab.txt` (as ubuntu) after copying the scripts below
to their places.

| When (UTC) | What |
|---|---|
| every 5 min | `~/treepnet-monitor.sh` (`monitor/`): health checks → Telegram |
| every 5 min | `refresh_story_visibility()` (`sql/stories_private_archive.sql`) |
| every hour | `postgrest/refresh-jwks.sh`: Google's token keys for PostgREST |
| 01:30 daily | PowerSync compact — drops superseded sync history so new devices download less; safe while the service runs |
| 22:30 daily | `~/treepnet-backup.sh` (`backup/`) |
| 23:30 Sun | `~/treepnet-backup-check.sh` |
| 23:55 daily | `~/analytics-rollup.sh` (`analytics/`): DAU/WAU/MAU snapshot for the admin panel |

## Where each file lives on the server

Everything the server runs is in this folder; the secrets (`.env`, the
service-account JSON, `postgrest/jwks.json`) come from the nightly backup.

| In the repo | On the server |
|---|---|
| `docker-compose.yml`, `sql/`, `functions/`, `powersync/`, `postgres/` | `~/treepnet/` (same layout) |
| `caddy/Caddyfile`, `caddy/web/` | `~/treepnet/caddy/` (reload: `docker exec treepnet-caddy caddy reload --adapter caddyfile --config /etc/caddy/Caddyfile`) |
| `../admin-panel/` (built `dist/`) | `~/treepnet/caddy/admin/` — see `admin-panel/README.md` |
| `postgrest/refresh-jwks.sh` | `~/treepnet/postgrest/refresh-jwks.sh` |
| `monitor/treepnet-monitor.sh`, `backup/*.sh`, `analytics/analytics-rollup.sh` | `~/` |
| `chatbackend-src/` | `~/treepnet/chatbackend/` |
| `crontab.txt` | ubuntu's crontab |

### Chat backend

`chatbackend-src/` is the code that runs (the upstream `messenger-chat-backend`
repo lacks our changes; the old `chatbackend-patches/` were folded in and
removed). Deploy with `chatbackend-src/deploy.sh`: it sends the files git
tracks, builds the image, runs `npm test` in it and only then makes
`~/treepnet/chatbackend/` exactly that folder and restarts chat
(`~/chat-deploys.log` records each one). Schema changes go first, by hand:
`chatbackend-src/prisma/manual/README.md`. Two files contain a literal NUL
inside a regex and one has CRLF line endings: edit them byte-safely, check with
`docker run --rm -v "$PWD":/app -w /app node:20-slim node --check <file>`, and
copy any change back here.

## Notes

- All secrets are injected at runtime (`${VAR}` from `.env`, mounted JSON
  files) — no credentials live in these committed files.
- Media is on OCI Object Storage (bucket `treepnet-media`), handled by the app
  directly, not by this stack.

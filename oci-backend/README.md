# TreepNet backend — OCI self-hosted stack

The self-hosted backend that replaced the Azure services, running via Docker
Compose on the OCI Ampere ARM (Always-Free) VM. This is a single `docker
compose up` stack; it supersedes the Azure-era `treepnet-push-func/` and
`treepnet-delete-account-func/` folders at the repo root (kept only for
reference).

The new app version talks to this stack; old store versions still hit Azure.

## Services (`docker-compose.yml`)

| Service | Image / build | Role |
|---|---|---|
| `caddy` | `caddy:2` | TLS (Let's Encrypt) + reverse proxy for the domains below |
| `postgres` | `postgres:16` | App database (`wal_level=logical` for PowerSync) |
| `powersync` | `journeyapps/powersync-service` | Sync service (reads → app) |
| `postgrest` | `postgrest/postgrest` | REST API (writes + RPCs), JWT via Entra JWKS |
| `pushworker` | `functions/push-worker` | Polls `push_outbox`, sends FCM v1 pushes |
| `deleteaccount` | `functions/delete-account` | Web "delete account" flow (email code + delete) |
| `errorlogger` | `functions/error-logger` | Forwards app crash/error reports to the private Telegram bot |

Public endpoints (Caddy): `https://sync.treepnet.com` → powersync,
`https://api.treepnet.com` → postgrest, `https://api.treepnet.com/delete-account/*`
→ deleteaccount, `https://api.treepnet.com/log/error` → errorlogger. Auth is
Microsoft Entra External ID (validated via its JWKS).

The `errorlogger` needs three env vars in `.env` (`TG_LOG_BOT_TOKEN`,
`TG_LOG_CHAT_ID`, `LOG_APP_KEY`). It has no database or secret-file dependency,
so deploying it is just: `docker compose up -d --build errorlogger` and then
reload Caddy for the new `/log/*` route
(`docker exec treepnet-caddy caddy reload --config /etc/caddy/Caddyfile`).

## Deploy

1. **Secrets (not in git — see `.gitignore`):**
   - `cp .env.example .env` and fill in real values.
   - Put the Firebase service-account JSON at `functions/fcm-service-account.json`.
   - Fetch the Entra JWKS for PostgREST:
     ```bash
     mkdir -p postgrest
     curl -s https://treepnet.ciamlogin.com/51c579e4-0e9f-4921-b96d-49470969c035/discovery/v2.0/keys \
       -o postgrest/jwks.json
     ```
     (Refresh this when Entra rotates its signing keys.)
2. **Bring it up:**
   ```bash
   docker compose up -d --build
   ```
   On first run, `postgres/initdb/01-powersync.sh` creates the PowerSync
   replication role + `powersync` publication. Then the schema: create the
   roles (`sql/setup-roles.sql`), run `sql/migrate.sh` (it builds everything
   from `sql/migrations/000_baseline.sql` on), and restore the app data into
   the `treepnet` database (the data dump is not kept in git).
3. **Verify:** the `sql/` helpers (`check-auth.sql`, `check-push.sql`,
   `verify.sql`, …) are diagnostic queries; `sql/setup-roles.sql` documents the
   `authenticator`/`authenticated` role setup PostgREST relies on.

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

`chatbackend-src/` is a snapshot of the code that runs (2026-10-31), with every
patch in `chatbackend-patches/` already applied (the upstream
`messenger-chat-backend` repo may not have them). To deploy it, copy the folder to
`~/treepnet/chatbackend/` (its `.env` comes from the backup) and run
`docker compose up -d --build chatbackend`. Two files contain a literal NUL
inside a regex and one has CRLF line endings: edit them byte-safely, check with
`docker run --rm -v "$PWD":/app -w /app node:20-slim node --check <file>`, and
copy any change back here.

## Notes

- All secrets are injected at runtime (`${VAR}` from `.env`, mounted JSON
  files) — no credentials live in these committed files.
- Media is on OCI Object Storage (bucket `treepnet-media`), handled by the app
  directly, not by this stack.

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

Public endpoints (Caddy): `https://sync.treepnet.com` → powersync,
`https://api.treepnet.com` → postgrest, `https://api.treepnet.com/delete-account/*`
→ deleteaccount. Auth is Microsoft Entra External ID (validated via its JWKS).

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
   replication role + `powersync` publication. Restore the app data into the
   `treepnet` database separately (the DB dump is not kept in git).
3. **Verify:** the `sql/` helpers (`check-auth.sql`, `check-push.sql`,
   `verify.sql`, …) are diagnostic queries; `sql/setup-roles.sql` documents the
   `authenticator`/`authenticated` role setup PostgREST relies on.

## Notes

- All secrets are injected at runtime (`${VAR}` from `.env`, mounted JSON
  files) — no credentials live in these committed files.
- Media is on OCI Object Storage (bucket `treepnet-media`), handled by the app
  directly, not by this stack.

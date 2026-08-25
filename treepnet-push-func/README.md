# TreepNet Push Function

Timer-triggered Azure Function (Node.js v4). Every 15s it reads `pending` rows
from `public.push_outbox` (filled by Postgres triggers — see
`New TreepNet/sql/push_notifications.sql`), looks up the recipient's
`profiles.push_token`, and sends a push via **FCM HTTP v1**.

## Prerequisites
1. Apply the SQL once: run `New TreepNet/sql/push_notifications.sql` against the
   Azure Postgres DB (psql).
2. A Firebase project with Cloud Messaging + a **service-account JSON**
   (Firebase Console → Project settings → Service accounts → Generate key).

## App settings (Azure Portal → Function App → Configuration)
Never commit these; set them in the Portal:
- `PG_CONNECTION_STRING` = `postgresql://USER:PASSWORD@HOST:5432/postgres?sslmode=require`
- `FCM_PROJECT_ID` = `treepnet-1fa8d`
- `FCM_SERVICE_ACCOUNT_JSON` = the entire service-account JSON, on one line
  (paste as a single value).

Also: allow the Function to reach Postgres — Azure Postgres → Networking →
"Allow public access from Azure services" (or add the Function's outbound IPs).

## Local run
```bash
cp local.settings.json.example local.settings.json   # fill in the values
npm install
func start
```

## Deploy
```bash
npm install
func azure functionapp publish <FUNCTION_APP_NAME> --javascript
```
(Same flow as the delete-account function. Node 20+ runtime, Linux Consumption.)

## Notes
- Idempotent claiming: rows are moved `pending → sending` with `claimed_at`;
  stale `sending` rows (>2 min) are reclaimed, so a crash never drops a push.
- Dead tokens (FCM `UNREGISTERED`/404) clear `profiles.push_token`.
- `notification`-type payloads → Android draws them itself when the app is
  backgrounded/terminated; the Flutter app draws foreground ones. `data` carries
  `type` + ids for tap routing.
- Latency ≈ up to 15s (timer interval). For near-instant delivery later, switch
  to a Postgres `LISTEN/NOTIFY` consumer or pg_cron→HTTP.

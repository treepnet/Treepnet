# Treepnet — web account-deletion backend

Backs `https://treepnet.com/delete-account`. Two HTTP endpoints:

| Endpoint | Body | Does |
|---|---|---|
| `POST /api/request-code` | `{ "username": "ra.adams" }` | Emails a 6-digit code to the account's email. Always returns `{ok:true}` (won't reveal if a username exists). |
| `POST /api/confirm` | `{ "username": "ra.adams", "code": "123456" }` | Verifies the code, then permanently deletes the account (`delete_account_by_id`). |

## 1. Apply the SQL first
Run `New TreepNet/sql/account_deletion_web.sql` against Azure Postgres. It creates
`account_deletion_codes` and `delete_account_by_id(uuid)`.

## 2. Configure (app settings / local.settings.json)
Copy `local.settings.json.example` → `local.settings.json` and fill in:

- **PG_CONNECTION_STRING** — admin connection string to Azure Postgres (`sslmode=require`).
- **SMTP_USER** — `treepnetofficial@gmail.com`.
- **SMTP_PASS** — a **Gmail App Password** (Google Account → Security → 2-Step
  Verification → App passwords). The normal Gmail password will NOT work.
- **ALLOWED_ORIGIN** — `https://www.treepnet.com` (must match the site origin for CORS).
- **CODE_TTL_MIN** — code lifetime in minutes (default 15).

## 3. Run locally
```
npm install
func start
```
Test: `curl -X POST http://localhost:7071/api/request-code -H "Content-Type: application/json" -d '{"username":"ra.adams"}'`

## 4. Deploy to Azure
1. Create a **Function App** (Node.js 20, Consumption) in the same region/subscription.
2. Set the same values in **Configuration → Application settings**.
3. Deploy: `func azure functionapp publish <your-function-app-name>`
   (or VS Code Azure Functions extension / GitHub Actions).
4. **Azure Postgres firewall**: allow the Function App's outbound IPs, or turn on
   "Allow public access from Azure services".
5. **CORS** (Function App → CORS): add `https://www.treepnet.com` (and `https://treepnet.com`).

## 5. Wire the website
In `treepnet-web/public/delete-account/index.html`, set:
```js
var API_BASE = 'https://<your-function-app-name>.azurewebsites.net/api';
```

## Notes
- Deleting the **Entra (Azure AD) login identity** is not done here (needs Microsoft
  Graph + admin). This deletes all app data in Postgres — same as the in-app
  "Settings → Delete account".
- Codes: 6 digits, expire in `CODE_TTL_MIN`, max 5 wrong attempts.
- Consider adding rate limiting (e.g. Azure API Management or a per-IP throttle)
  before going fully public.

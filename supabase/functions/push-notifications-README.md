# FCM push notifications (app closed / backgrounded)

The in-app badge + Notifications feed already work. This adds **system-tray push
notifications** that arrive even when TreepNet is closed, using **FCM HTTP v1**
sent from a **Supabase Edge Function** (`push-on-message`).

> Why not from the app? The old client code called Google's legacy
> `fcm/send` endpoint (shut down June 2024) with a server key. FCM v1 needs an
> OAuth2 token minted from a Firebase **service account** — a secret that must
> live on a backend, never inside the app.

Firebase project: **treepnet-16a89** (already wired via `google-services.json`).

---

## Step 1 — Get a Firebase service-account key
1. Firebase Console → your project (**treepnet-16a89**) → ⚙️ **Project settings**.
2. Tab **Service accounts** → **Generate new private key** → **Generate key**.
3. A JSON file downloads (contains `client_email` + `private_key`). Keep it
   secret — do NOT commit it.

## Step 2 — Store it as a Supabase secret
Install the Supabase CLI if needed (`npm i -g supabase`), then from the repo:

```bash
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>

# Load the service account JSON as a secret (one line):
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat /path/to/service-account.json)"
```
`<YOUR_PROJECT_REF>` is in your Supabase dashboard URL:
`https://supabase.com/dashboard/project/<PROJECT_REF>`.

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically — no
need to set them.

## Step 3 — Deploy the function
```bash
supabase functions deploy push-on-message --no-verify-jwt
```
`--no-verify-jwt` is required because the Database Webhook calls it without a
user JWT.

Function URL becomes:
`https://<PROJECT_REF>.supabase.co/functions/v1/push-on-message`

## Step 4 — Trigger it on every new message
Supabase Dashboard → **Database** → **Webhooks** → **Create a new hook**:
- **Name**: `push_on_message`
- **Table**: `public.messages`
- **Events**: ✅ Insert
- **Type**: HTTP Request → **POST**
- **URL**: the function URL from Step 3
- **HTTP Headers**: add `Content-Type: application/json`

Save. Now every message inserted into Supabase (i.e. after PowerSync uploads a
sent message) fires the webhook → the Edge Function pushes to the receiver.

---

## Test
1. Make sure both phones have the latest APK and are logged in (each stored its
   `push_token` in `profiles` on login).
2. **Fully close** TreepNet on phone B (swipe it away).
3. From phone A, send phone B a message.
4. Phone B should get a system notification: **"<sender>": <message text>**.

Debug: Supabase Dashboard → Edge Functions → `push-on-message` → **Logs**.
Each call returns `{ ok, status, fcm }` — `ok:true` means FCM accepted it.

## Notes / next steps
- This covers **messages**. Likes / follows can get push too by adding webhooks
  on `public.likes` / `public.subscriptions` that call sibling functions with
  the same OAuth helper (ask and I'll add them).
- Foreground (app open) still uses the in-app badge + Notifications feed — FCM
  `notification` payloads only auto-display in the tray when the app is
  backgrounded/closed, which is the intended behavior.
- If a device has no `push_token` yet (never logged in on this build), the
  function safely skips it.

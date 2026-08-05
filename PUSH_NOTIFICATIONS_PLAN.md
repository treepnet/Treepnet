# Push Notifications — Implementation Plan (TreepNet)

Status: IN PROGRESS. Goal: like / comment / follow / follow_request / chat message
events reach the phone's notification tray **even when the app is closed**.

### Progress (2026-08-05)
- [x] Phase 1 — Firebase project `treepnet-1fa8d` created; `google-services.json`
      (dev package only) placed in `android/app/`; service-account key downloaded
      by user (kept off-repo). TODO: add prod package `com.treepnet.application`
      to Firebase before a prod/Play build.
- [x] Phase 2 — Client code DONE: deps (firebase_core/messaging,
      flutter_local_notifications), gradle (google-services plugin + desugaring),
      `POST_NOTIFICATIONS` + FCM channel/icon in manifest,
      `lib/notifications/push/push_notifications.dart` + `push_notification_listener.dart`,
      wired in bootstrap (init), app_view (register on auth), app_bloc (clear on logout).
- [x] Phase 3 — Backend code DONE (not yet applied/deployed):
      `New TreepNet/sql/push_notifications.sql` (push_outbox + 4 triggers),
      `~/Desktop/treepnet-push-func/` (timer Function, FCM v1). USER must: apply SQL,
      deploy Function, set PG_CONNECTION_STRING + FCM_PROJECT_ID + FCM_SERVICE_ACCOUNT_JSON,
      open Postgres to Azure services.
- [ ] Phase 4 — Test on device (two accounts). Build/install pending.
- [ ] Phase 5 — Store compliance.

## Current state (verified)
- No Firebase, no FCM, no `firebase_messaging`, no `POST_NOTIFICATIONS`, no
  `google-services.json`. Push was removed during the Supabase→Azure migration
  (see comment in `lib/app/bloc/app_bloc.dart`).
- Scaffolding that REMAINS: `User.pushToken` field + `profiles.push_token` column;
  `UserProfileBloc` already forwards `pushToken` to `updateUser(...)`.
- Notifications today = in-app only, built by a PowerSync query
  (`database_client.dart` `notificationsOf`): types `like`, `comment`, `follow`,
  `follow_request` (from `subscriptions`). Chat = separate `messages` table.
- Writes: PowerSync `uploadData` → PostgREST → Postgres tables. So **every**
  like/comment/subscription/message lands in a Postgres table → Postgres
  AFTER INSERT triggers are the client-agnostic place to fire push.
- iOS: `Info.plist` already has `UIBackgroundModes: remote-notification`.

## Architecture (recommended)
```
 client writes (like/comment/follow/msg)
        │  PowerSync → PostgREST
        ▼
 Postgres table  ──AFTER INSERT trigger──▶  push_outbox (status='pending')
                                                   │
                        Azure Function (timer ~10s / or pg_cron+http)
                                                   │ read pending
                                                   │ lookup recipient push_tokens
                                                   ▼
                                        FCM HTTP v1  ──▶  Google FCM ──▶ phone
                                                   │
                                          mark sent / failed (+retry)
```
Why an **outbox + Azure Function** (not a direct trigger→FCM call): FCM HTTP v1
needs a short-lived OAuth token from a Google service account — awkward from
inside Postgres. The outbox makes sending retryable, observable, and decoupled.
We already run Azure Functions (delete-account) and pg_cron, so this fits.

**Firebase is required** — but ONLY as the FCM transport. On Android, Google's
FCM is the only channel to a closed app; Azure Notification Hubs would still
deliver via FCM/APNs underneath. So: create a FREE Firebase project used solely
for Cloud Messaging. It does not touch Azure Postgres / PowerSync / Entra / Blob.

---

## Phase 0 — Decisions (LOCKED 2026-08-05)
- [x] Platform scope: **Android-first**. iOS is a later phase (needs Apple Dev
      account + APNs .p8). Do NOT wire iOS FCM yet.
- [x] Event scope: **ALL** — chat message, follow, follow_request, comment, like.
      (Likes can be noisy — consider a collapse_key / per-type mute later, but v1
      sends all five.)

## Phase 1 — Firebase FCM project (transport only)
1. Create a Firebase project (console.firebase.google.com) — no Analytics needed.
2. Add Android app with applicationId `com.treepnet.application` (and `.dev` for
   the dev flavor as a second app, or reuse one) → download **google-services.json**
   → place in `android/app/`.
3. (iOS, if in scope) Add iOS app → **GoogleService-Info.plist** into `ios/Runner/`;
   upload the **APNs auth key** (.p8 from Apple Developer) into Firebase → Cloud
   Messaging settings.
4. Project settings → Service accounts → **Generate new private key** → JSON.
   This is the backend credential (goes into the Azure Function settings, NOT git).

## Phase 2 — Client (Flutter): receive + register token
Files/areas: `pubspec.yaml`, `android/`, a new `lib/notifications/push/` service,
`app_bloc` / login flow, `AndroidManifest.xml`.
1. Add deps: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`.
2. Android Gradle: add `com.google.gms:google-services` plugin + apply in
   `android/app/build.gradle`; ensure `google-services.json` per flavor.
3. `firebase_core` init in `main()` (both `main_development.dart` /
   `main_production.dart`).
4. Permission: add `POST_NOTIFICATIONS` to manifest; request it **in-context**
   (first time the user lands on the notifications tab OR right after first login) —
   consistent with our "no up-front permission" rule
   (see memory `permission-request-in-context-only`).
5. Token lifecycle (new `PushNotificationService`):
   - on login / app-start (authenticated): `getToken()` → save to
     `profiles.push_token` via existing `updateUser(pushToken:)`.
   - `onTokenRefresh` → update stored token.
   - on **logout**: clear the token (so a signed-out phone stops getting pushes) —
     important, do in `AppLogoutRequested`.
6. Receive/display:
   - Foreground: `FirebaseMessaging.onMessage` → show via
     `flutter_local_notifications` (FCM does not auto-display in foreground).
     Suppress a chat push if the user is currently inside that same chat.
   - Background/terminated: send **notification-type** FCM messages → the OS
     displays them automatically. Tapping opens the app.
   - Tap routing: `onMessageOpenedApp` + `getInitialMessage()` → go_router to the
     right screen (notifications page, or the specific chat) using `data` payload.
7. Multi-device: prefer a small `push_tokens` table (user_id, token, platform,
   updated_at) over the single `profiles.push_token` column, so a user logged in
   on 2 devices gets push on both. (Can start with the single column and migrate.)

## Phase 3 — Backend: enqueue + send
SQL (new file `sql/push_notifications.sql`):
1. `push_tokens` table (if multi-device) + `push_outbox` table
   (id, recipient_id, type, title, body, data jsonb, status, attempts,
   created_at, sent_at). These are backend-only → **not** synced to clients, so no
   PowerSync bucket/publication needed (unlike synced tables — cf. memory
   `invite-badge-pending-sql`). Still grant the roles the Function connects as.
2. AFTER INSERT triggers on `likes`, `comments`, `subscriptions`, `messages`:
   - compute recipient (post owner / subscribed_to_id / message peer),
   - skip self-actions (actor == recipient),
   - build title/body ("username liked your post", "username sent you a message"),
   - INSERT into `push_outbox` (status='pending').
Azure Function (`~/Desktop/treepnet-push-func/` or reuse an app):
3. Trigger: **timer** every ~10–15s (simple) — or pg_cron calls its HTTP endpoint,
   or LISTEN/NOTIFY for lower latency. Start with timer.
4. Logic: `SELECT ... FROM push_outbox WHERE status='pending' LIMIT N` →
   for each, look up recipient token(s) → call **FCM HTTP v1**
   (`https://fcm.googleapis.com/v1/projects/<id>/messages:send`) with an OAuth
   token minted from the service-account JSON (`google-auth-library`) →
   mark `sent`; on failure increment `attempts`, retry with backoff; on
   `UNREGISTERED`/`404` delete the dead token.
5. Settings (Azure Portal, not git): `PG_CONNECTION_STRING`,
   `FCM_SERVICE_ACCOUNT_JSON` (or key vault ref), `FCM_PROJECT_ID`.

## Phase 4 — Test (two accounts / two devices)
- Closed-app push for each event type; foreground, background, terminated.
- Tap → correct screen. Token refresh. Logout stops pushes. Permission denied path.
- Verify no self-notifications; no duplicate on retries (idempotent outbox).

## Phase 5 — Store compliance
- `POST_NOTIFICATIONS` is normal-level → no Play declaration needed.
- Data Safety: push token is collected → declare "App activity / device IDs" as
  appropriate. iOS: notifications entitlement + APNs.

---

## Effort / dependencies summary
- Hard external deps: Firebase project (free), service-account key; iOS also needs
  Apple Dev account + APNs .p8.
- Rough size: Client ~1–1.5 days, Backend SQL+Function ~1 day, test ~0.5 day
  (Android only). iOS adds ~0.5 day + Apple setup.
- Secrets: user creates them in Firebase/Azure Portal; assistant never handles
  live secrets on disk (established rule).

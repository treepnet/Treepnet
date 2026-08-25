# TreepNet — Referral / App Links deploy steps

Everything in the **app** is ready. These are the remaining **server + Play Console**
steps to make invite links work end-to-end.

Final identifiers (already set in all files here):
- Android package: `com.treepnet.application`
- Invite link shape: `https://treepnet.com/invite/<handle>`
- Play referrer key the app reads: `treepnet_invite=<handle>`

## 1. Host the association + invite files on treepnet.com
Serve these at the exact paths (no file extension on the association files):

| File (in this folder) | URL it must be reachable at |
|---|---|
| `assetlinks.json` (same as `well-known-treepnet/assetlinks.json`) | `https://treepnet.com/.well-known/assetlinks.json` |
| `apple-app-site-association` | `https://treepnet.com/.well-known/apple-app-site-association` |
| `invite_index.html` | served for every `https://treepnet.com/invite/<handle>` |

- `.htaccess` → put next to the association files so they are served as `application/json`.
- `root.htaccess` → rename to `.htaccess` at the site root; it rewrites `/invite/<handle>` to the invite page.
- Both association files must be served over **HTTPS**, `200 OK`, content-type `application/json`, **no redirects**.

## 2. After the app is uploaded to Google Play
1. Play Console → **Setup → App signing** → copy the **App signing key certificate SHA-256**.
2. In BOTH `assetlinks.json` files, replace `REPLACE_WITH_PLAY_APP_SIGNING_SHA256`
   with that value. (The first fingerprint — `5B:90:…:5B:7C` — is the upload key
   and is already correct.)
3. Re-deploy the updated `assetlinks.json`.
   - Verify: https://developers.google.com/digital-asset-links/tools/generator
     and open `https://treepnet.com/.well-known/assetlinks.json` in a browser.

## 3. iOS (later, when the app is on the App Store)
- In `apple-app-site-association`, replace `REPLACE_TEAM_ID` with the Apple **Team ID**
  (bundle id `com.treepnet.application` is already correct).
- In `invite_index.html`, set `IOS_APP_ID` (e.g. `id1234567890`).

## 4. Wire the site's "Google Play" button
Point it at:
`https://play.google.com/store/apps/details?id=com.treepnet.application`

## How the flow then works
- App installed → tap `https://treepnet.com/invite/<handle>` → App Link opens the app →
  handle redeemed → referrer's "Registered" count goes up.
- App NOT installed → tap link → `invite_index.html` → Play Store with
  `referrer=treepnet_invite=<handle>` → after install the app reads the referrer →
  redeemed automatically on first sign-in.

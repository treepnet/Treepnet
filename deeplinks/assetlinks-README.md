# Android App Links (deep-link auto-open) for treepnet.app

Referral / share links like `https://treepnet.app/invite/<user>` and
`https://treepnet.app/<user>` currently open the website, not the app. To make
Android open TreepNet directly (App Links), you need three pieces:

## 1. Host `assetlinks.json`
Publish `assetlinks.template.json` (in this folder) at exactly:

```
https://treepnet.app/.well-known/assetlinks.json
```

It must be served over HTTPS, with `Content-Type: application/json`, no
redirects. Replace the placeholders first (step 2).

## 2. Fill in the package name + signing fingerprint
- **package_name**: the flavor you ship.
  - dev: `com.emilzulufov.flutter_instagram_offline_first_clone.dev`
  - production: your production applicationId.
- **sha256_cert_fingerprints**: the SHA-256 of the keystore you SIGN the
  released app with. Get it with:

```bash
# From android/ — for the debug key:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA256

# Or a full report for all variants:
cd android && ./gradlew signingReport
```
Copy the `SHA256:` value (colon-separated hex) into the array. You can list
several fingerprints (debug + release).

## 3. Declare the App Link intent-filter in AndroidManifest
In `android/app/src/main/AndroidManifest.xml`, inside the main `<activity>`, add
an `autoVerify` intent filter for the host:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="treepnet.app" />
</intent-filter>
```

Then handle the incoming URI in the app's router (go_router already parses the
path, e.g. `/invite/:handle`).

## Verify
After hosting + rebuilding:
```bash
adb shell pm verify-app-links --re-verify com.emilzulufov.flutter_instagram_offline_first_clone.dev
adb shell pm get-app-links com.emilzulufov.flutter_instagram_offline_first_clone.dev
```
Tapping a `https://treepnet.app/...` link should now open TreepNet.

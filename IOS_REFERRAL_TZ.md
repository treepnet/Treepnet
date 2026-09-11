# iOS Referral — Texnik topshiriq (TZ)

Holat: **reja tasdiqlandi, amalga oshirilmoqda**
Sana: 2026-09-11

## 1. Maqsad
iOS'да referral (taklif) tizimini Android bilan bir xil natijaga imkon qadar
yaqinlashtirish. Ikki mustaqil qism:

- **A. Universal Links** — ilova O'RNATILGAN iOS foydalanuvchi `treepnet.com/invite/<handle>`
  ni bossa, brauzer emas, ILOVA ochilsin (feed yoki auth).
- **B. Deferred (clipboard)** — ilova O'RNATILMAGAN yangi foydalanuvchi uchun:
  taklif kodini clipboard orqali ilovaga yetkazish, App Store install'dan keyin
  register'da hisoblansin.

Server tomoni (redeem RPC, referrals jadval, `redeem_referral` qoidasi) Android
bilan BIR XIL — o'zgarmaydi. Faqat kod ilovaga yetkazish yo'li iOS'da farq qiladi.

## 2. Qaror qilingan tanlovlar
- **Deferred usuli:** Clipboard (fingerprint EMAS, ChottuLink EMAS). Sabab:
  ~85-95% aniqlik, bepul, tashqi bog'liqliksiz, App Store xavfsiz, mavjud
  infrani (marketing sayt + backend) qayta ishlatadi.
- **Landing:** Alohida sahifa YO'Q. iOS'da `/invite/<handle>` mavjud MARKETING
  saytini ko'rsatadi; undagi "App Store" tugmasi bosilganda kodni clipboard'ga
  yozadi + App Store'ga o'tadi (bitta tap, ortiqcha sahifa yo'q).
- **Paste banner:** v1'da oddiy variant — iOS tizim banneri ("TreepNet pasted
  from Safari") birinchi ochilishda 1 marta chiqadi (matn o'zgartirib bo'lmaydi).
  Native `detectValues` bilan banner'ni butunlay yo'qotish — ixtiyoriy Phase-2.
- **HMAC imzo:** v1'da YO'Q. Abuzani mavjud himoyalar cheklaydi (qat'iy format +
  handle real username bo'lishi shart + faqat yangi register + unique invited_id +
  self rad). HMAC — ixtiyoriy Phase-2 qattiqlashtirish.
- **Android:** TEGILMAYDI. `/invite/*` Android'da hozirgidek ko'rinmas 302 → Play
  (install-referrer). Clipboard faqat iOS.

## 3. Ma'lum qiymatlar
- App Store ID: `6801508746` (apps.apple.com/uz/app/treepnet/id6801508746)
- Apple Team ID: `YR6Y9NXLYK`
- Bundle id (prod): `com.treepnet.application`
- Bundle id (dev): `com.treepnet.application.dev`
- Domen: `treepnet.com` (Cloudflare Worker `treepnet-web`)
- Clipboard kod formati: `treepnet_invite=<handle>`

---

## 4. Foydalanuvchi oqimlari (kutilgan natija)

### 4.1 Universal Link — ilova bor
1. `treepnet.com/invite/<handle>` bosiladi.
2. iOS AASA'ni tekshiradi → ILOVA ochiladi (brauzer emas).
3. Ilova (app_links) handle'ni oladi. Login bor → feed; login yo'q → auth.
4. (Mavjud user login qilsa hisoblanmaydi; yangi register'da hisoblanadi.)

### 4.2 Deferred (clipboard) — ilova yo'q
1. `treepnet.com/invite/<handle>` bosiladi.
2. Ilova yo'q → Worker MARKETING saytini ko'rsatadi (URL'da handle qoladi).
3. User "App Store" tugmasini bosadi → `treepnet_invite=<handle>` clipboard'ga
   yoziladi + App Store ochiladi.
4. User o'rnatadi + birinchi ochadi → ilova clipboard'ni o'qiydi → handle →
   saqlaydi → clipboard'ni tozalaydi.
5. User register qilsa → taklif hisoblanadi.

### 4.3 Oddiy (taklifsiz) user
- `treepnet.com/` (root) → marketing sayt. App Store tugmasi'da handle YO'Q →
  copy qilinmaydi, faqat App Store. Ilova buferni o'qiydi → format mos emas →
  hech kimga hisoblanmaydi. Xato/bug yo'q.

---

## 5. Amalga oshiriladigan o'zgarishlar

### 5.1 AASA fayl (Cloudflare / treepnet-web)
Yangi fayl: `treepnet-web/public/.well-known/apple-app-site-association` (kengaytmasiz).
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": ["YR6Y9NXLYK.com.treepnet.application",
                   "YR6Y9NXLYK.com.treepnet.application.dev"],
        "components": [{ "/": "/invite/*" }]
      }
    ]
  }
}
```
- `application/json` bilan berilishi kerak (Worker'da content-type; SPA fallback
  ushlamasligi kerak). `/invite/*` yo'llari App Link sifatida ochiladi.
- Tekshiruv: Apple CDN `applinks.apple.com` va real qur-da.

### 5.2 iOS entitlements
`ios/Runner/Runner.entitlements` va `ios/Runner/RunnerRelease.entitlements` ga:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:treepnet.com</string>
</array>
```
- Apple Developer portalda App ID'ga **Associated Domains** capability yoqilgan
  bo'lishi kerak (Xcode managed signing bilan avtomat, yoki portalda qo'lda) —
  **user amaliyoti** (Apple hisobi). Yangi provisioning profil kerak bo'ladi.

### 5.3 Info.plist — URL scheme (custom scheme fallback)
`ios/Runner/Info.plist` CFBundleURLSchemes — Supabase qoldig'ini almashtirib
`treepnet` qo'shish:
```xml
<key>CFBundleURLSchemes</key>
<array>
  <string>treepnet</string>
</array>
```
(Google OAuth scheme kerak bo'lsa saqlanadi; Supabase `io.supabase.flutterquickstart`
olib tashlanadi — tekshirib.)

### 5.4 Cloudflare Worker (treepnet-web/worker.js)
`/invite/<handle>` uchun UA bo'yicha:
- **Android** → hozirgidek 302 → Play (`referrer=treepnet_invite=<handle>`), no-store.
- **iOS** → 302 EMAS. MARKETING saytini ko'rsatadi (`env.ASSETS.fetch`, URL o'zgarmaydi),
  toki React handle'ni o'qiy olsin.
- **Desktop/boshqa** → marketing sayt (yoki Play listing) — marketing sayt.
- `/.well-known/apple-app-site-association` → `application/json` bilan berish.
- `run_worker_first: ["/invite/*"]` allaqachon bor (SPA fallback'dan oldin worker).

### 5.5 Marketing sayt (treepnet-web, React)
`src/App.jsx`:
- URL'dan invite handle o'qish: `location.pathname` `/invite/<handle>` bo'lsa → state.
- **App Store tugmasi** (`id6801508746`): agar handle bor bo'lsa, onClick:
  1. `treepnet_invite=<handle>` ni clipboard'ga yoz (sinxron `execCommand('copy')`
     yoki `await navigator.clipboard.writeText`),
  2. keyin `window.location = "https://apps.apple.com/uz/app/treepnet/id6801508746"`.
  Handle yo'q bo'lsa — oddiy havola (copy yo'q).
- Google Play tugmasi — o'zgarmaydi (Android clipboard ishlatmaydi).

### 5.6 Ilova (Flutter, iOS)
- `ReferralConfig` — Universal Link + custom scheme `treepnet://invite/<handle>`
  ni ham parse qilishi (mavjud `handleFromUri` tekshiriladi).
- **Yangi: iOS birinchi-ochilish clipboard o'qish** (`lib/referral/`):
  - Faqat iOS, faqat birinchi marta (shared_preferences flag `ios_clip_checked`).
  - `Clipboard.getData` → `treepnet_invite=<handle>` qat'iy formatni tekshir →
    `PendingReferral.save(handle)` → clipboard'ni tozala (bo'sh setData).
  - Universal Link'dan handle kelgan bo'lsa, clipboard o'qishni o'tkazib yubor.
  - `ReferralLinkListener` yoki alohida init'da chaqiriladi (app_links bilan yonma-yon).
- Redeem — MAVJUD oqim (`sign_up_cubit` → `redeemReferral`) o'zgarmaydi.

---

## 6. Chetki holatlar (hal qilingan)
- Oddiy user App Store tugmasi'ni bossa → handle yo'q → copy yo'q → hisoblanmaydi.
- Bufer boshqa narsa bilan almashsa → taklif o'tkazib yuboriladi (xato emas).
- Mavjud user link bossa → login → redeem yo'q (yangi register qoidasi).
- Self/takror → server rad etadi.
- Android'da clipboard umuman ishlamaydi → aralashuv yo'q.

## 7. Fazalar (bajarish tartibi)
- **Faza 1 — Universal Links (server + iOS config):** AASA + entitlements +
  Info.plist scheme + Worker (iOS marketing) + deploy + tekshirish.
- **Faza 2 — Clipboard deferred:** React App Store tugmasi (copy) + Flutter iOS
  birinchi-ochilish clipboard o'qish + tekshirish.
- **Faza 3 (ixtiyoriy):** native `detectValues` (banner'siz) va/yoki HMAC imzo.

## 8. Testlash rejasi
- AASA: `applinks.apple.com` orqali va real iPhone/TestFlight'da link bosish.
- Universal Link (ilova bor): link → ilova ochiladi (feed/auth).
- Deferred: yangi iPhone (ilova yo'q) → link → marketing → App Store tugmasi →
  install → ochilish → register → `referrals`da hisoblanganini tekshirish.
- Oddiy user: root sayt → App Store → install → register → hisoblanMAGANini tekshirish.

## 9. User (Apple hisobi) amaliyotlari
- App ID'ga Associated Domains capability yoqish (Xcode/portal).
- (Kerak bo'lsa) yangi provisioning profil / imzo.
- TestFlight build (real qurilmada Universal Link + deferred sinash uchun).

---
Server (redeem/referrals/qoida) va Android — TEGILMAYDI. Faqat iOS yetkazish qatlami.

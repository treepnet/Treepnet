# iOS Push Notifications — Setup & Status

Firebase Cloud Messaging (FCM) → APNs transport. Android tomoni tayyor; bu hujjat
iOS uchun. Branch: `fix/ios-location-and-push-permissions`.

Firebase project: `treepnet-1fa8d` (project number `349647020201`).
Bundle id'lar: `com.treepnet.application` (prod), `.dev`, `.stg`.
Apple Developer team: `YR6Y9NXLYK`.

---

## ✅ Kodda bajarilgan (commit qilishga tayyor)

- **Entitlements — APNs muhiti to'g'irlandi (asosiy prod tuzatish).**
  - `Runner/Runner.entitlements` → `aps-environment = development` — faqat **Debug**
    config'larda (Xcode'dan qurilmaga run = sandbox APNs).
  - `Runner/RunnerRelease.entitlements` → `aps-environment = production` — **Release**
    va **Profile** config'larda (arxiv / TestFlight / App Store = production APNs).
  - `project.pbxproj`: 3 Debug config → development, 6 Release/Profile → production.
  - **Nega muhim:** ilgari barcha config `development` edi. Prod build sandbox token
    olardi, Firebase esa production APNs'ga yuborardi → **prod'da push jimgina
    kelmasdi**. Endi har bir config to'g'ri muhitga bog'langan.
- `Info.plist`: `UIBackgroundModes` = `fetch` + `remote-notification` ✓.
- Swizzling yoniq (`FirebaseAppDelegateProxyEnabled` o'chirilmagan) → APNs token
  registratsiyasi avtomatik; `AppDelegate.swift` stock holatda yetarli ✓.
- Dart ulanishi to'liq: `bootstrap` → `initialize()`; auth bo'lganda
  `PushNotificationListener` → `registerForUser()` (in-context permission + token
  saqlash); logout'da `disableForUser()` (token o'chirish).
- Foreground notification **o'chiq** (qasddan): app ochiq turganda hech qanday
  push ko'rsatilmaydi; chat push'i faqat app background/yopiq bo'lganda OS orqali
  keladi. Boshqa turlar ham hozircha faqat background'da.
- **Flavor-aware GoogleService-Info.plist** o'rnatildi:
  - Plist'lar `ios/config/<flavor>/GoogleService-Info.plist` da turadi
    (`dev` / `stg` / `prod`). Hozir `prod` bor.
  - Build phase "[Firebase] Copy GoogleService-Info.plist" flavor'ga qarab
    to'g'ri plist'ni build'dagi `.app` ichiga nusxalaydi. Plist yo'q flavor →
    nusxalanmaydi → Firebase o'tkazib yuboriladi (dev simulator oqimi buzilmaydi).
  - `.gitignore`: `ios/config/*/GoogleService-Info.plist` — plist'lar lokalda
    qoladi, repoga chiqmaydi (Android `google-services.json` bilan bir xil).

---

## ❌ FOYDALANUVCHI bajarishi shart (kod bilan qilib bo'lmaydi — konsollar)

Bularsiz iOS'da push **umuman ishlamaydi**. Real qurilma ham kerak (Simulator
haqiqiy APNs token olmaydi).

### 1. Apple Developer — App ID + Push capability
- developer.apple.com → Certificates, IDs & Profiles → Identifiers.
- Har bir bundle id (`com.treepnet.application`, kerak bo'lsa `.dev`/`.stg`) uchun
  **Push Notifications** capability'ni yoqing.

### 2. Apple Developer — APNs Auth Key (.p8)
- Keys → **+** → "Apple Push Notifications service (APNs)" belgilang → Register.
- **`.p8` faylni yuklab oling** (bir marta beriladi!), **Key ID** va **Team ID**ni
  yozib qo'ying.

### 3. Firebase — iOS app qo'shish + APNs key yuklash
- console.firebase.google.com → `treepnet-1fa8d` → Project settings → **Your apps**
  → Add app → **iOS**. Bundle id: `com.treepnet.application` (prod). Kerak bo'lsa
  `.dev` va `.stg` uchun ham alohida iOS app qo'shing.
- Har biri uchun **`GoogleService-Info.plist`** yuklab oling.
- Project settings → **Cloud Messaging** → Apple app configuration → **APNs Auth Key**
  bo'limiga 2-qadamdagi `.p8` + Key ID + Team ID'ni yuklang.

### 4. `GoogleService-Info.plist`'ni loyihaga qo'shish  ✅ (prod bajarildi)
- Setup allaqachon **flavor-aware** qilib o'rnatilgan (yuqoriga qarang). Faqat
  kerakli flavor'ning plist'ini to'g'ri papkaga tashlash kifoya:
  - prod → `ios/config/prod/GoogleService-Info.plist`  ✅ (joyida)
  - dev  → `ios/config/dev/GoogleService-Info.plist`   (real qurilmada dev push
    test qilmoqchi bo'lsangiz: Firebase'ga `com.treepnet.application.dev` iOS app
    qo'shing → plist yuklab shu yerga tashlang)
  - stg  → `ios/config/stg/GoogleService-Info.plist`   (kerak bo'lsa)
- Boshqa hech narsa shart emas — build phase o'zi to'g'ri plist'ni tanlaydi.

### 5. Provisioning profiles (prod = Manual signing)
- Prod config'lar Manual signing ishlatadi (profile: "MacBook Pro",
  identity: iPhone Distribution). Push yoqilgan App ID bilan **distribution
  provisioning profile**ni qayta generatsiya qilib, Xcode'da tanlang.
- dev/stg = Automatic signing → Xcode o'zi hal qiladi.

---

## Test (real qurilmada)
1. `flutter run --flavor development -t lib/main_development.dart -d <ios-device>`.
2. Login → permission so'raladi → ruxsat bering → token `profiles.push_token`'ga
   saqlanadi (loglardan tekshiring).
3. Backend'dan (yoki Firebase Console → Cloud Messaging → test) push yuboring:
   app yopiq/background'da tray'da ko'rinishi kerak.
4. Prod tekshiruvi: `flutter build ipa --flavor production` → TestFlight → real
   push. (Endi production entitlement bilan token production APNs'ga mos keladi.)

# Texnik Topshiriq — Auth migratsiyasi: Microsoft Entra → Firebase (Variant A)

**Versiya:** 1.0  **Sana:** 2026-08-28  **Branch:** `oci-integration`
**Variant:** A — Firebase **custom token**, `uid = UUID`, sxema o'zgarmaydi, parol hash'i o'zimizda.

---

## 1. Maqsad va doira

**Maqsad:** Ilova autentifikatsiyasini Microsoft Entra External ID'dan Firebase'ga
ko'chirish. Natijada Microsoft/Azure'ga **hech qanday** bog'liqlik qolmaydi
(backend allaqachon OCI'da). Ilova UI'si — login, signup, reset ekranlari —
**piksel-piksel o'zgarmaydi**.

**Doira ichida:**
- Yangi `firebase_authentication_client` (mavjud `AuthenticationClient` interfeysini implement qiladi).
- Yangi backend `auth-service` (custom token minting + parol tekshirish + email OTP).
- Backend token validatsiyasini Firebase'ga o'tkazish (PowerSync + PostgREST + RLS).
- Entra kodini **saqlab qolish** (rollback uchun), yangi kod bilan almashtirish.

**Doiradan tashqari:**
- Google/Apple ijtimoiy login (hozir UI'da o'chirilgan — shundayligicha qoladi).
- Real foydalanuvchi/parol migratsiyasi (data sandbox — noldan boshlanadi).
- Media, push, delete-account funksiyalarining o'zgarishi (auth token ishlatmaydi — tegilmaydi).

---

## 2. Arxitektura (Variant A)

```
┌────────────┐   1. login/signup+OTP    ┌──────────────────┐
│  Flutter   │ ───────────────────────▶ │  auth-service     │  (yangi, Node)
│   ilova    │                          │  - bcrypt parol   │
│            │   2. Firebase custom     │  - email OTP      │
│            │ ◀─── token (uid=UUID) ─── │  - Firebase Admin │──▶ mint custom token
└────┬───────┘                          └────────┬─────────┘
     │ 3. signInWithCustomToken(token)           │ profiles(id=UUID) yozadi
     ▼                                           ▼
 Firebase SDK ──▶ ID token (sub = UUID)     PostgreSQL (OCI)
     │
     │ 4. Bearer <ID token>
     ▼
 PowerSync + PostgREST  ──validate──▶ Firebase JWKS,  sub = UUID = profiles.id
```

**Asosiy g'oya:** parolni Firebase EMAS, o'z `auth-service`'imiz tekshiradi
(bcrypt hash DB'da). Muvaffaqiyatli tekshiruvdan keyin Firebase Admin SDK
orqali `uid = profiles.id` (UUID) bo'lgan **custom token** yaratiladi. Ilova uni
`signInWithCustomToken` bilan almashtirib, `sub = UUID` bo'lgan Firebase ID token
oladi. Shu bilan `profiles.id` `uuid` tipida qoladi va backend faqat `oid → sub`
renaming qiladi.

---

## 3. Ma'lumot modeli (PostgreSQL — OCI)

`profiles` jadvali **o'zgarmaydi** (`id uuid PRIMARY KEY`). Qo'shiladigan narsalar:

### 3.1. Parol saqlash
`profiles`'ga ustun qo'shiladi (yoki alohida `auth_credentials` jadvali):
```sql
ALTER TABLE profiles ADD COLUMN password_hash text;  -- bcrypt, faqat auth-service o'qiydi/yozadi
```
> RLS: `password_hash` hech qachon PostgREST/PowerSync orqali klientga chiqmasligi
> kerak. auth-service superuser (RLS bypass) bilan ulanadi; PostgREST'ning
> `authenticated` roli uchun bu ustunga `SELECT` grant **berilmaydi**.

### 3.2. Email OTP kodlari (signup + reset)
Mavjud `account_deletion_codes` andozasida:
```sql
CREATE TABLE auth_codes (
  email       text PRIMARY KEY,
  code        text NOT NULL,
  purpose     text NOT NULL,          -- 'signup' | 'reset'
  payload     jsonb,                   -- signup uchun: {username, full_name, birthday, password_hash}
  expires_at  timestamptz NOT NULL,
  attempts    int NOT NULL DEFAULT 0
);
```
> Signup'da profil kod tasdiqlangunча yaratilmaydi — pending ma'lumot `payload`'da turadi.

---

## 4. Backend — `oci-backend/functions/auth-service/`

Yangi Node HTTP servis (delete-account bilan bir xil uslub: `pg` + `nodemailer`
+ `firebase-admin`). Caddy orqali `https://api.treepnet.com/auth/*`.

### 4.1. Bog'liqliklar
```json
{ "pg": "^8", "nodemailer": "^6", "firebase-admin": "^12", "bcryptjs": "^2" }
```
Firebase Admin — mavjud `functions/fcm-service-account.json` xizmat akkаunti bilan
init (custom token minting uchun **Service Account Token Creator** huquqi kerak;
`firebase-adminsdk` akkаuntida odatda mavjud).

### 4.2. Endpointlar
| Metod + yo'l | Kirish | Ish | Chiqish |
|---|---|---|---|
| `POST /auth/signup/send-code` | email, username, password, fullName, birthday? | username/email bandligini tekshir → bcrypt hash → `auth_codes`'ga (purpose=signup, payload) yoz → OTP email | `{ok:true, codeLength:6}` |
| `POST /auth/signup/verify` | email, code | kodни tekshir → `profiles`(id=gen UUID, username, …, password_hash) yoz → **custom token** (uid=UUID) → kodни o'chir | `{token}` |
| `POST /auth/login` | usernameOrEmail, password | username→email hал → bcrypt solishtir → **custom token** (uid=profiles.id) | `{token}` |
| `POST /auth/reset/send-code` | usernameOrEmail | email OTP (purpose=reset) | `{ok:true, codeLength:6}` |
| `POST /auth/reset/verify` | email, code, newPassword | kodни tekshir → `password_hash` yangila | `{ok:true}` |
| `POST /auth/verify-password` | usernameOrEmail, password | akkаunt o'chirishдан oldin re-auth uchun | `{ok:true}` |

**Umumiy talablar:**
- Barcha javob `ok`/`error` JSON; username probing'ga qarshi noaniq xatolar.
- OTP: 6 xonа, TTL 15 daq, ≤5 urinish (delete-account'даги logика).
- CORS faqat kerakli origin; rate-limit (IP bo'yicha oddiy).
- `PG_CONNECTION_STRING` — superuser (RLS bypass, `password_hash`'ga kirish uchun).

### 4.3. Custom token minting
```js
const admin = require('firebase-admin');
const token = await admin.auth().createCustomToken(profileId /* UUID */);
```
> Bu Firebase Auth'да `uid = profileId` bo'lgan minimal user yozuvини yaratadi
> (email/parolsiz). Klient `signInWithCustomToken(token)` bilan ID token oladi.

---

## 5. Backend — token validatsiyasi (Firebase'ga o'tkazish)

Firebase ID token: `iss = https://securetoken.google.com/treepnet-1fa8d`,
`aud = treepnet-1fa8d`, `sub = uid = UUID`. JWKS:
`https://www.googleapis.com/service_accounts/v1/jwks/securetoken@system.gserviceaccount.com`.

| Fayl | O'zgarish |
|---|---|
| `oci-backend/powersync/service.yaml` | `jwks_uri` → Firebase JWKS; `audience` → `treepnet-1fa8d` |
| `oci-backend/powersync/sync-config.yaml` | `request.jwt() ->> 'oid'` → `->> 'sub'` (**7 joy**) |
| `oci-backend/docker-compose.yml` | `PS_JWKS_URL` → Firebase JWKS; `PGRST_JWT_AUD` → `treepnet-1fa8d`; `PGRST_JWT_ISS`(ixtiyoriy) |
| `postgrest/jwks.json` | Firebase JWKS'ni fetch (Entra o'rniga); rotatsiyada yangilanadi |
| DB — RLS siyosatlari | `auth.uid()` funksiyasi `... ->> 'oid'` → `... ->> 'sub'` o'qisin |
| Caddy `Caddyfile` | `handle_path /auth/* → auth-service:PORT` qo'shish |

> **Diqqat:** `oid → sub` **hamma joyda** izchil bo'lishi shart, aks holda
> qatorlar ko'rinmay qoladi yoki RLS rad etadi. Test bilan tasdiqlash majburiy.

---

## 6. App tomoni (Flutter)

### 6.1. Yangi paket: `firebase_authentication_client`
Entra client'ni andoza qilib, `AuthenticationClient` interfeysini implement qiladi.
Bog'liqliklar: `firebase_auth`, `firebase_core` (core allaqachon FCM uchun bor),
`dio`/`http` (auth-service chaqiruvи uchun), `token_storage`.

| Interfeys metodи | Yangi implementatsiya |
|---|---|
| `logInWithPassword` | `POST /auth/login` → `signInWithCustomToken(token)` → `AuthSession`'ni yangila |
| `signUpSendCode` | `POST /auth/signup/send-code` |
| `signUpVerifyCode` | `POST /auth/signup/verify` → `signInWithCustomToken` |
| `resetPasswordSendCode` / `resetPasswordSubmit` | `POST /auth/reset/send-code` / `/verify` |
| `isUsernameAvailable` | PostgREST'дан (hozirgidek) yoki `/auth`'дан |
| `logInWithGoogle`/`Github` | `throw ... not enabled` (hozirgidek) |
| `logOut` | `FirebaseAuth.instance.signOut()` + `AuthSession.clear()` + `db.disconnectAndClear()` |
| `user` stream | `AuthSession.changes` → `AuthenticationUser` |
| `restoreSession` | Firebase sessiyani avtomatik saqlaydi: startupда `currentUser != null` bo'lsa `getIdToken()` olib publish |

### 6.2. `token_storage` — umumlashtirish
`EntraSession`/`EntraTokens` → `AuthSession`/`AuthTokens` (nom neytral).
- `userId` getter: `claims['sub']` (Entra'даги `oid` o'rniga).
- Firebase ID token'ni `AuthTokens.idToken`'ga solamiz; `claims` = decode qilingan payload.
- Refresh: Firebase SDK avtomatik; `registerRefresher` → `getIdToken(forceRefresh:true)`.

### 6.3. `powersync_repository`
`EntraSession` → `AuthSession` (minimal). `fetchCredentials`, `uploadData`,
`postgrest()` — o'sha mantiq, faqat token manbаsi `AuthSession`. `Bearer <idToken>`
o'zgarmaydi.

### 6.4. `main_development/production/staging.dart`
`EntraAuthenticationClient(...)` → `FirebaseAuthenticationClient(...)`;
`Firebase.initializeApp()` allaqachon bor (FCM). `restoreSession()` chaqiruvи qoladi.

### 6.5. Tegilmaydigan joylar (UI)
`login_cubit`, `sign_up_cubit`/`state`/`page`, `settings_page`, `security_page`
— **interfeys orqали**, kod o'zgармайди. (`security_page` matni ixtiyoriy l10n
yangilanishi: "managed by Microsoft" → neytral.)

---

## 7. Bajarilish tartibi (implementation plan)

1. **DB tayyorlash** (sandbox): `profiles.password_hash` ustunи, `auth_codes` jadvali, RLS grant'larни moslash.
2. **`auth-service` yozish** — 6 endpoint, Firebase Admin custom token, bcrypt, nodemailer. Docker + Caddy `/auth/*`.
3. **Backend validatsiya** — service.yaml + sync-config `oid→sub` + docker-compose Firebase JWKS/aud + jwks.json fetch + RLS `oid→sub`. `docker compose up -d --build`.
4. **`token_storage` umumlashtirish** — `AuthSession`/`AuthTokens`, `userId=sub`.
5. **`firebase_authentication_client`** — interfeys implementatsiyasi (Entra andoza).
6. **`powersync_repository` + `main_*`** — `AuthSession`'ga ulash, Firebase client'ни DI.
7. **pubspec** — `firebase_auth` qo'shish; `entra_authentication_client` olib tashlash (yoki qoldirib, ishlatmaslik — rollback uchun).
8. **Test** (§8) — signup, login, sync, reset, delete, restart.
9. **l10n + testlar** yangilash; Entra kodини `_deprecated`/branch'да saqlash.

> Entra kodи 5-6-qadamgача **saqlanadi**; almashtirish oxirида, ishlaganдан keyin qilinadi.

---

## 8. Test rejasi (qabul mezonlari — Definition of Done)

- [ ] **Signup:** yangi email → OTP keladi → tasdiqlash → `profiles`'da `id` UUID, username to'g'ri → ilovaga kiradi.
- [ ] **Login:** username bilan + parol → kiradi; noto'g'ri parol → "Wrong username or password".
- [ ] **Sync:** kirgach PowerSync ID token bilan ulanadi (`sub`), o'z ma'lumotlari sync bo'ladi; **begona userning maxfiy buketlari kelmaydi** (RLS/oid→sub tekshiruvи).
- [ ] **Yozuv:** post/story yaratish PostgREST orqали o'tadi (`Bearer` ID token qabul qilinadi).
- [ ] **Reset:** OTP bilan parol yangilanadi → yangi parol bilan kiriladi.
- [ ] **Delete (in-app):** parol re-auth (`/auth/verify-password`) → akkаunt o'chadi → Firebase user ham o'chadi.
- [ ] **Restart:** ilova qayta ochilganда sessiya saqlanadi (`currentUser` → getIdToken).
- [ ] **`password_hash` sizmaydi:** PostgREST/PowerSync orqали hech qачон chiqmaydi.
- [ ] **Microsoft yo'q:** kodda/traffikда Entra/ciamlogin/onmicrosoft chaqiruvи qolmaganи tekshiriladi.

---

## 9. Xavflar va yumshatish

| Xavf | Yumshatish |
|---|---|
| Parol xavfsizligини o'zимиз boshqaramiz | `bcryptjs` (cost ≥ 10), `password_hash` faqat superuser; PostgREST grant yo'q; TLS majburiy |
| OTP brute-force | 6 xonа + TTL 15daq + ≤5 urinish + rate-limit (delete-account andozаsи) |
| `oid→sub` bir joyда qolib ketsa | Test §8 (begona buket kelmaslиги); grep bilan `oid` qidiruvи |
| Custom token creator huquqи yo'q | IAM'да `Service Account Token Creator` rolini tekshirish/berish |
| Firebase JWKS rotatsiyasi | `jwks.json`'ni davriy fetch (cron), PowerSync `jwks_uri` avtomatik |
| Rollback kerak bo'lса | Entra client + Entra backend config saqlangан; `oci-integration`'да branch/flag bilan qaytariladi |

> **Muqobil (kelajak optimizatsiyasi):** custom token o'rniga o'z RS256 kalitимиз
> bilan JWT imzolash Firebase'ни butunlай chetlаб o'tardi. Hozir Firebase tanlanган
> (SDK sessiya boshqaruvи + auto-refresh uchun); bu TT Firebase custom token'ga asoslanган.

---

## 10. Konfiguratsiya / sirlar

| Nom | Manba | Joy |
|---|---|---|
| Firebase service account | mavjud `functions/fcm-service-account.json` | auth-service init (qayta ishlatiladi) |
| Firebase project id | `treepnet-1fa8d` | service.yaml, docker-compose |
| Firebase JWKS URL | `https://www.googleapis.com/service_accounts/v1/jwks/securetoken@system.gserviceaccount.com` | service.yaml, jwks fetch |
| SMTP (OTP email) | mavjud `SMTP_PASS` (Gmail app parol) | auth-service env |
| DB superuser | mavjud `.env` | auth-service `PG_CONNECTION_STRING` |

Barcha sirlar `.env`/mount orqали; kodда qattiq-kod yo'q (oci-backend qoidаsи).

---

## 11. Taxminiy hajm

~2 kun: backend `auth-service` + validatsiya (~1 kun), app client + integratsiya + test (~1 kun).
UI o'zgармайди. Yakunда Microsoft/Azure'ga bog'liqlik **0**.

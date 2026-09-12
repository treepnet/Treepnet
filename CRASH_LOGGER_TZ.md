# Treepnet Crash/Error Logger — Texnik topshiriq (TZ)

Holat: **reja — tasdiq kutilmoqda**
Sana: 2026-09-12

## 1. Maqsad
Ilovadagi **xato / crash / bug**larni (faqat shularni) yig'ib, **Treepnet'ning
o'z Telegram botiga** yuborish. HTTP request/response, info-log, user tracking —
YO'Q. Maxfiylik-xavfsiz (token/PII/body yubormaydi). Ishlayotgan API/UI/oqimlarga
tegmaydi — passiv kuzatuvchi.

## 2. Nima ushlaydi / ushlamaydi
**Ushlaydi (Dart darajasi):**
- Flutter/widget xatolari — `FlutterError.onError` (mavjud hook).
- Uncaught async/Dart crash — `runZonedGuarded` (mavjud hook).
- Bloc xatolari — `AppBlocObserver.onError` (mavjud hook).
- Qo'lda: `CrashReporter.report(error, stack, {context})` — try/catch bloklarida.

**Ushlamaydi:**
- HTTP request/response (interceptor QO'YILMAYDI).
- info/warning spam, user harakati, PII.
- ⚠️ Haqiqiy NATIVE crash (SIGSEGV, native plugin) — Dart bilan ushlab bo'lmaydi.
  v1 doirasidan tashqarida; kerak bo'lsa keyin Firebase Crashlytics qo'shiladi
  (Firebase allaqachon bor).

## 3. Arxitektura
```
Ilova (CrashReporter)  →  [HTTPS]  →  OCI backend (/log/error)  →  Telegram bot
        │                                     │
   offline queue                    dedup + rate-limit + (ixtiyoriy) Postgres saqlash
```
- **Bot token — SERVER env'da** (secret). Ilova binary'ida ham repo'da ham YO'Q.
- Ilova faqat o'z backend'iga (api.treepnet.com/log/error) yuboradi.

## 4. Qaror qilingan tanlovlar
- **Yetkazish:** backend proxy (token server'da) — token-in-app EMAS.
- **Native crash:** v1'da YO'Q (Dart error/crash yetarli). Crashlytics — ixtiyoriy
  keyingi faza.
- **Lokal saqlash:** drift/sqlite YO'Q (telegram_logger ortiqcha ishlatgan) —
  offline uchun kichik JSON queue (shared_preferences).
- **Branding:** "Treepnet" (katta N emas).

## 5. Ma'lumot modeli (payload — faqat xavfsiz maydonlar)
```json
{
  "kind": "flutter | zone | bloc | manual",
  "message": "<error.toString(), <= 1000 belgi>",
  "stack": "<yuqori ~15 frame>",
  "screen": "<joriy route yoki null>",
  "appVersion": "1.0.2",
  "build": "3",
  "platform": "ios | android",
  "os": "iOS 18.0",
  "device": "iPhone15,2",
  "env": "prod | dev | staging",
  "userId": "<profiles.id UUID yoki null>",
  "ts": "2026-09-12T13:40:00Z",
  "signature": "<hash(kind+message+top frame) — dedup uchun>"
}
```
❌ YUBORILMAYDI: header, Authorization/token, request/response body, ism, telefon,
email. `userId` — faqat anonim UUID (ixtiyoriy; xohlansa umuman yuborilmaydi).

## 6. Ilova tomoni (Flutter) — `lib/monitoring/`
`crash_reporter.dart` — `CrashReporter`:
- `init()` — kontekstni (versiya, qurilma, env) bir marta yig'adi; offline
  queue'ni flush qiladi.
- `report(Object error, StackTrace? stack, {String kind, String? screen})`:
  1. Payload yasaydi (xavfsiz maydonlar, stack'ni ~15 frame'ga kesadi).
  2. **signature** hisoblaydi; oxirgi N soniyada (masalan 60s) bir xil signature
     bo'lsa — tashlab yuboradi (client dedup).
  3. **rate-limit:** sessiyada/daqiqada cap (masalan 20).
  4. **Fire-and-forget** HTTP POST → `/log/error`. Xato bo'lsa — **offline queue**ga
     (shared_prefs, cap 50), keyingi `init`da yuboriladi.
  5. **Butun metod try/catch ichida — hech qachon throw qilmaydi.**
- Kontekst manbalari: `package_info_plus` (versiya), `device_info_plus`
  (qurilma/OS), router observer (joriy ekran), `AppBloc` (user id), flavor (env).

**Wiring — `lib/bootstrap.dart` (mavjudni ALMASHTIRMASDAN, ustiga qo'shib):**
- `FlutterError.onError`: `logE(...)` (mavjud) + `CrashReporter.report(..., kind: 'flutter')`.
- `runZonedGuarded` onError: `logE(...)` + `report(..., kind: 'zone')`.
- `AppBlocObserver.onError`: `report(..., kind: 'bloc')`.
- `CrashReporter.init()` — bootstrap boshida (kontekst + queue flush).

## 7. Backend (OCI) — kichik Node servis `errorlog` (yoki auth-service'ga route)
Endpoint: `POST /log/error`
- Payloadni oladi (JSON schema tekshiruvi).
- **Server dedup/aggregate:** bir xil signature 5 daqiqada bir marta yuboriladi,
  takrorlar soni bilan ("🔁 x3").
- **Rate-limit** (IP bo'yicha) — flood himoyasi.
- **Yengil app-key** (header) — casual abuse'ni filtrlash (kuchli sirt emas,
  chunki binary'da; asosiy himoya rate-limit + dedup).
- **Telegram'ga** `sendMessage` (bot token + chat_id ENV'dan).
- **Ixtiyoriy:** `error_logs` Postgres jadvaliga saqlash (tarix/qidiruv).
- Caddy: `api.treepnet.com/log/*` → shu servis.
- ENV (secret): `TG_LOG_BOT_TOKEN`, `TG_LOG_CHAT_ID`, `LOG_APP_KEY`.
- Deploy: docker-compose (push-worker/auth-service pattern).

## 8. Telegram xabar formati
```
🚨 Treepnet ERROR — prod
📍 /feed
❌ Bad state: No element
📂 feed_bloc.dart:88 › _mapEventToState
📱 iPhone15,2 · iOS 18.0 · 1.0.2 (3)
👤 5adde07a…
⏰ 2026-09-12 13:40 UTC
🔁 x3 (5 daqiqada)     ← dedup bo'lsa
```

## 9. Xavfsizlik qoidalari (majburiy)
1. **Augment, almashtirma** — mavjud error-handlerlar (logE + default) saqlanadi.
2. **Reporter hech qachon throw qilmaydi** — hammasi try/catch.
3. **Fire-and-forget** — UI bloklanmaydi, jank yo'q.
4. **Dedup + rate-limit + cap** — error-storm'da flood/batareyka yo'q.
5. **Jim fail** — backend/tarmoq o'chiq bo'lsa retry-storm yo'q; offline queue.
6. **PII/token/body yo'q** — dizaynda.
7. **HTTP interceptor yo'q** — ishlayotgan oqimlarga tegmaydi.

## 10. Fazalar
- **Faza 1 — Ilova:** `CrashReporter` + kontekst + offline queue + dedup/rate-limit
  + bootstrap wiring. (Backend'siz ham konsolda ishlaydi.)
- **Faza 2 — Backend:** `errorlog` servis + Telegram forward + dedup + deploy.
- **Faza 3 — Test:** test-xato → Telegram; offline→flush; dedup/spam; build.
- **Faza 4 (ixtiyoriy):** native crash uchun Crashlytics; `error_logs` Postgres UI.

## 11. Sizdan kerak (user)
1. @BotFather → `/newbot` → **bot token**.
2. Loglar uchun Telegram guruh/kanal + botni qo'shish → **chat_id** (topishga
   yordam beraman).
3. `TG_LOG_BOT_TOKEN` + `TG_LOG_CHAT_ID`ni OCI server env'iga qo'yish (secret;
   o'zingiz yoki ruxsat bilan men).

## 12. Testlash rejasi
- Ilovada ataylab xato → Telegram botga to'g'ri format bilan kelishi.
- Airplane mode → xato queue'ga → qayta ulanganda yuborilishi.
- Bir xil xatoni ko'p marta → Telegram to'lmasligi (dedup/rate-limit).
- Simulyator + real qurilmada build.

## 13. Non-goals (v1)
- HTTP request/response logging.
- Analytics / user behaviour tracking.
- Native crash (SIGSEGV) — keyingi faza (Crashlytics).
- PII yig'ish.

---
Ilova o'zgarishlari keyingi relizda ketadi; backend qismi mustaqil deploy bo'ladi.
Bot token repo'da/binary'da hech qachon bo'lmaydi.

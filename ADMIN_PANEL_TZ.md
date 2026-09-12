# Treepnet Admin Panel (Statistika) — Texnik topshiriq (TT)

Holat: **reja — tasdiq kutilmoqda**
Sana: 2026-09-12
Turi: ichki analitika dashboard (read-only), moderatsiya EMAS

## 1. Maqsad
`admin.treepnet.com` — ichki **statistika paneli**: nechta user, post, story,
register, referral, **DAU/WAU/MAU** va boshqa metrikalar. Faqat **o'qish** (hech
narsa yozilmaydi/o'chirilmaydi). Custom kod deyarli yo'q — **Metabase** (ochiq
kodli BI) ishlatiladi.

**Asosiy prinsip:** ilova (Flutter) kodiga UMUMAN tegilmaydi → yangi client bug,
UI regressiya, funksiya buzilishi xavfi ~nol. O'zgarish faqat backend/infra +
bitta sinxronlanmaydigan ustun.

## 2. Umumiy arxitektura
```
Sizning brauzeringiz
   │ HTTPS (login: Metabase o'z akkaunti)
   ▼
Caddy  ──►  admin.treepnet.com  (+ admin.130-61-138-104.sslip.io fallback)
   │            │ IP allowlist (ixtiyoriy)
   ▼            ▼
        Metabase container (JVM, -Xmx1g, mem_limit)
          │ metadata (o'z config'i)      │ so'rovlar (faqat o'qish)
          ▼                              ▼
   Postgres: `metabase` DB          Postgres: `treepnet` DB
   (metabase_app rol)               analytics_ro rol → FAQAT `analytics` VIEW'lar
                                    (PII/parol/xabar matni KO'RINMAYDI)
```

## 3. Qaror qilingan tanlovlar
1. **Asbob:** Metabase (custom React panel EMAS) — klik bilan dashboard, tez,
   xavfsiz, bepul.
2. **DAU/WAU/MAU:** mavjud `profiles.last_seen_at` dan (allaqachon butun ilova
   bo'ylab 45s heartbeat bilan yangilanadi — `presence_heartbeat.dart`). Ilovaга
   qo'shimcha YO'Q. Snapshot (hozirgi holat), tarixiy trend keyingi fazada.
3. **Register vaqti:** `auth_credentials.created_at` (sinxronlanmaydigan jadval),
   `profiles`ga EMAS. Sabab: `profiles` `select *` bilan **global** sinxronlanadi
   (`sync-config.yaml`), unga ustun qo'shish hamma clientга ta'sir qiladi.
   `auth_credentials`ni faqat auth-service ishlatadi → 0 sync ta'sir, auth-service
   kodi ham o'zgarmaydi (`DEFAULT now()` avtomatik to'ldiradi).
4. **Xavfsizlik:** read-only rol + faqat PII-siz `analytics` VIEW'lar +
   `statement_timeout` + Metabase o'z login/2FA + IP allowlist (ixtiyoriy).
5. **Izolyatsiya:** Metabase o'z metadata bazasi (`metabase` DB, alohida rol) —
   jonli `treepnet` bazasidan ajratilgan.

## 4. Metrikalar katalogi
Belgilar: 🟢 hozir · 🟡 `created_at` bilan · 🔵 keyingi faza · 🔴 imkonsiz (event
tracking kerak).

**Umumiy KPI:** jami user/post/story/comment/referral 🟢 · DAU/WAU/MAU 🟢 ·
stickiness (DAU/MAU) 🟢 · bugungi yangi user 🟡

**O'sish:** kunlik/oylik yangi register 🟡 · kumulyativ o'sish 🟡 · profil
to'liqligi (avatar/bio) 🟢 · private vs ochiq 🟢 · push-token qamrovi 🟢 · yosh
taqsimoti (birth_year) 🟢

**Faollik:** DAU/WAU/MAU snapshot 🟢 · faollik segmentlari (1/7/30 kun) 🟢 ·
uxlab qolganlar (30+ kun) 🟢 · DAU/WAU/MAU tarixiy trend 🔵 · sessiya vaqti 🔴 ·
retention cohort 🔴

**Postlar:** kunlik postlar 🟢 · kontent yaratuvchilar soni 🟢 · o'rt. post/user
🟢 · joylashuv teglangan ulush 🟢 · top like/komment olgan postlar 🟢

**Storylar:** kunlik storylar 🟢 · faol (muddati o'tmagan) 🟢 · rasm/video 🟢 ·
highlight 🟢

**Muloqot:** kunlik like/komment 🟢 · javob-komment ulushi 🟢 · o'rt. like/post
🟢 · saqlangan (bookmark) 🟢 · engagement rate 🟢

**Ijtimoiy graf:** jami/kunlik follow 🟢 · top follower'li userlar 🟢 · follow
so'rovlari 🟢 · 0-follower ulushi 🟢

**Referral:** jami/kunlik referral 🟢 · leaderboard 🟢 · tier taqsimoti 🟢 ·
referral orqali kelgan ulush 🟡 · link→register konversiya 🔴

**Chat:** jami suhbat 🟢 · kunlik xabar 🟢 · xabar turi (matn/rasm/video/ovoz) 🟢
· faol suhbatchilar 🟢

**Geografiya:** top davlat/region/joy 🟢 · postlar xaritasi (heatmap) 🟢 · tashrif
buyurgan regionlar (`visited_regions`) 🟢 · eng ko'p sayohatchilar 🟢

**Xavfsizlik signallari:** bloklashlar soni 🟢 · eng ko'p bloklangan userlar 🟢 ·
report/ban 🔴 (funksiya yo'q)

**Tizim:** push navbati holati/muvaffaqiyat 🟢 · crash/error statistikasi 🔵
(`error_logs` jadvali kerak)

## 5. Ma'lumot manbalari va migration
Yagona schema o'zgarishi:
```sql
ALTER TABLE auth_credentials ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
```
- Sinxronlanmaydigan jadval → PowerSync'ga ta'sir yo'q.
- Mavjud qatorlar migration vaqtini oladi (real signup vaqti emas, lekin bundan
  keyingi barcha register aniq). **Backfill (UPDATE) qilinmaydi** — sync bo'ronidan
  qochish uchun.
- auth-service INSERT (`insert into auth_credentials(user_id, password_hash)`)
  `created_at`ni `DEFAULT now()` bilan avtomatik oladi → kod o'zgarmaydi.

DAU/WAU/MAU manbasi: `profiles.last_seen_at` (allaqachon mavjud, ishlab turibdi).

## 6. Backend komponentlari

### 6.1. Analytics VIEW'lar (`analytics` schema)
Faqat **agregatga xavfsiz** ustunlar. **Hech qachon kirmaydi:** email, parol
hash, OTP kod, push_token, to'liq ism, xabar/komment **matni**, avatar/media URL.
- `analytics.signups` — user_id, created_at (register trendi)
- `analytics.users` — id, username, has_avatar, has_bio, is_private,
  referral_tier, birth_year, last_seen_at, signup_at
- `analytics.posts` — id, user_id, created_at, has_location, country/region/name
- `analytics.stories` — id, user_id, created_at, expires_at, content_type
- `analytics.comments` — id, post_id, user_id, created_at, is_reply
- `analytics.likes` — id, post_id, comment_id, user_id, created_at
- `analytics.follows` — subscriber_id, subscribed_to_id, created_at
- `analytics.referrals` — referrer_id, invited_id, created_at
- `analytics.messages` — id, conversation_id, from_id, type, created_at
- `analytics.conversations` — id, created_at
- `analytics.blocked` — blocker_id, blocked_id, created_at
- `analytics.visited_regions` — user_id, region_iso, created_at
- `analytics.push` — recipient_id, type, status, created_at, sent_at
- Rollup: `analytics.active_users` (dau/wau/mau), `analytics.kpis` (jami sanoqlar)
VIEW'lar egasi (superuser) asosiy jadvallarга kiradi; `analytics_ro` faqat
view'larni ko'radi (PG16 definer-view) → asosiy jadvallarга to'g'ridan-to'g'ri
kira olmaydi.

### 6.2. Read-only rol
```sql
CREATE ROLE analytics_ro LOGIN PASSWORD '<generated>';
GRANT USAGE ON SCHEMA analytics TO analytics_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO analytics_ro;
ALTER ROLE analytics_ro SET default_transaction_read_only = on;
ALTER ROLE analytics_ro SET statement_timeout = '60s';
ALTER ROLE analytics_ro SET idle_in_transaction_session_timeout = '30s';
```
`public` schema jadvallariga grant berilmaydi. Parol serverda `.env`da, repo'да
emas.

### 6.3. Metabase container (docker-compose)
```yaml
metabase:
  image: metabase/metabase:v0.51.x   # aniq versiyaga pin
  restart: unless-stopped
  depends_on: [postgres]
  environment:
    MB_DB_TYPE: postgres
    MB_DB_HOST: postgres
    MB_DB_PORT: "5432"
    MB_DB_DBNAME: metabase
    MB_DB_USER: metabase_app
    MB_DB_PASS: ${METABASE_DB_PASS}
    JAVA_TOOL_OPTIONS: "-Xmx1g"        # heap cheklovi
  mem_limit: 1600m                     # OOM'дан himoya (swap yo'q)
  networks: [treepnet]
```
Metadata bazasi: `CREATE DATABASE metabase OWNER metabase_app;` (jonli
`treepnet`дан ajratilgan).

### 6.4. Caddy (subdomain)
```
admin.treepnet.com, admin.130-61-138-104.sslip.io {
    # @office { remote_ip <SIZNING_IP>/32 }   # ixtiyoriy IP allowlist
    # handle @office { reverse_proxy metabase:3000 }
    # respond 403
    reverse_proxy metabase:3000
}
```
`sslip.io` fallback → DNS'siz ham darhol ishlaydi.

## 7. Login / kirish
- Metabase'ning **o'z** login tizimi (ilova useridan alohida).
- **Register YO'Q** (ochiq sayt emas). Birinchi ochilganда **setup wizard** — SIZ
  admin akkaunt (email + parol) yaratasiz. Parolni faqat siz bilasiz.
- Tayyor login/parol berilmaydi (xavfsizlik + siyosat). Wizard ~1 daqiqa.
- Kirgach: **2FA yoqish** tavsiya etiladi. Boshqa adminlarни taklif qilish mumkin.
- Data source: Metabase'да `treepnet` bazasini `analytics_ro` bilan qo'shasiz
  (host: postgres, port 5432, db: treepnet, user: analytics_ro, parol: beriladi).

## 8. Xavfsizlik qoidalari (majburiy)
1. `created_at` → `auth_credentials` (profiles EMAS; sync bo'roni yo'q).
2. Read-only rol; `default_transaction_read_only=on`; write grant yo'q.
3. Faqat `analytics` VIEW'lar; PII/parol/OTP/token/xabar matni ko'rinmaydi;
   `auth_credentials`/`auth_codes`ga grant yo'q.
4. Metabase: alohida metadata DB; JVM heap + `mem_limit` cheklovi; kuchli
   parol + 2FA; yangilanib turadi (CVE); public sharing o'chiq.
5. `statement_timeout` — qochib ketgan so'rov jonli bazani sekinlata olmaydi.
6. Kirish: sslip.io/subdomain HTTPS; IP allowlist (ixtiyoriy) yoki hech bo'lmasa
   kuchli parol+2FA.
7. Parollar serverда `.env`, repo/binary'da emas.

## 9. Xavflar va oldini olish
| Xavf | Jiddiylik | Oldini olish |
|---|---|---|
| Og'ir so'rov jonli bazani sekinlatadi | 🔴→🟢 | statement_timeout, caching, kichik pool, off-peak, (ixtiyoriy) read-replica |
| PII/parol sizishi | 🔴→🟢 | faqat PII-siz view'lar; auth_credentials/auth_codes grant yo'q |
| Metabase hujum yuzasi (CVE, brute-force) | 🔴→🟡 | IP allowlist/2FA/patch; read-only+view zararni cheklaydi |
| RAM OOM (swap yo'q) → app container o'lishi | 🟡 | -Xmx1g + mem_limit; RAM monitoring (hozir ~10GB bo'sh) |
| Postgres ulanish tugashi | 🟡 | kichik Metabase pool; max_connections zaxirasi |
| `last_seen_at` qurilma soati (skew) | 🟢 | so'rovда `last_seen_at <= now()` bilan kesish |
| Metabase metadata jonli bazaga aralashishi | 🟡 | alohida `metabase` DB + rol |

## 10. Resurs rejasi (serverdagi holat)
- RAM: 11GB jami, ~10GB bo'sh (containerlar ~440MB). Metabase ~1-1.5GB —
  qulay. **Swap yo'q** → `mem_limit` majburiy.
- CPU: **2 yadro** — asosiy cheklov. `statement_timeout` + caching + off-peak
  bilan jonli yukdan himoya.
- Disk: 180GB bo'sh — muammosiz.

## 11. Fazalar
- **Faza 1 (asosiy):** migration + read-only rol + view'lar + Metabase container +
  Caddy subdomain + deploy. Natija: `admin.…sslip.io` ochiladi, setup wizard.
- **Faza 2:** dashboard'lar yasash (KPI, O'sish, Kontent, Engagement, Geografiya,
  Tizim) — Metabase'да klik bilan. DNS `admin.treepnet.com` ulanadi.
- **Faza 3 (ixtiyoriy):** IP allowlist / 2FA majburlash; scheduled email report.
- **Faza 4 (kelajak):** kunlik snapshot cron (`metrics_daily` → tarixiy DAU/WAU/MAU
  trendi); `error_logs` jadvali (crash statistikasi); read-replica; PostHog (chuqur
  engagement).

## 12. Men qiladigan ish vs Siz qiladigan ish
**Men (serverда):** migration, rol, view'lar, grantlar, Metabase container +
metadata DB, Caddy subdomain, deploy, verifikatsiya (sslip.io ochilishi),
dashboard'larни boshlab berish.
**Siz:** (1) Metabase setup wizard — o'z admin akkaunt; (2) DNS: Cloudflare'да
`admin.treepnet.com` → 130.61.138.104 (A, proxy OFF) — ixtiyoriy, sslip.io
darhol ishlaydi; (3) ixtiyoriy: IP allowlist uchun IP manzilingiz.

## 13. Qaytarib olish (reversibility)
Hammasi qo'shimcha va izolyatsiyalangan: ustun `DROP COLUMN`, Metabase container
`down`, rollar `DROP ROLE`, Caddy blok o'chiriladi. **Ilovani qayta build/deploy
qilish shart emas.**

## 14. Doiradan tashqari (v1)
- Moderatsiya/report/ban (funksiya yo'q — alohida loyiha).
- Sessiya vaqti, ekran funnel, retention cohort, feed impression (event tracking
  yoki PostHog kerak).
- DAU/WAU/MAU tarixiy trend (Faza 4 — kunlik snapshot).
- Kontentni tahrirlash/o'chirish (read-only panel).

---
Ilova (Flutter) tegilmaydi. Yagona schema o'zgarishi — sinxronlanmaydigan
`auth_credentials.created_at`. Barcha parollar serverда `.env`da.

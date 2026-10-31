# Messenger Chat Backend

`messenger-chat-plugin` uchun backend: 1:1 suhbatlar, real vaqtda xabar
almashish, media yuklash, presence.

Bu CRM chat backendidan **ajratib olingan** — faqat messenger uchun kerak
bo'lgan qismlar. Operator/admin paneli, staff boshqaruvi va CRM tiketlari
bu yerda yo'q.

## Talablar

- Node.js 18+
- PostgreSQL 14+
- Redis (loyiha va foydalanuvchi keshi uchun; ishlamasa server baribir
  ishlaydi, shunchaki sekinroq)

## Ishga tushirish

```bash
npm install
cp .env.example .env.local     # qiymatlarni to'ldiring
npx prisma db push             # jadvallarni yaratadi
npm start
```

`http://localhost:3000/health` javob bersa — tayyor.

## Autentifikatsiya

Alohida ro'yxatdan o'tish yo'q. Mijoz har bir so'rovda sarlavha yuboradi:

| Sarlavha | Majburiy | Izoh |
|---|---|---|
| `x-uuid` | ha | Foydalanuvchining ilovadagi identifikatori |
| `x-app-key` | ha | Loyiha kaliti (`Project.apiKey`) |
| `x-app` | ha | Loyiha nomi |
| `x-device-id`, `x-device-name`, `x-device-type` | ha | Qurilma ma'lumoti |
| `x-lang` | ha | Til kodi |
| `x-name`, `x-phone`, `x-email` | yo'q | Berilsa profilga yoziladi |

Foydalanuvchi birinchi murojaatda avtomatik yaratiladi.

## REST

| Metod | Yo'l | Vazifa |
|---|---|---|
| GET | `/chat/dm/me` | O'z profilim |
| GET | `/chat/dm/users?q=` | Yozish mumkin bo'lgan foydalanuvchilar |
| GET | `/chat/dm/conversations` | Suhbatlar ro'yxati (oxirgi xabar, o'qilmaganlar) |
| POST | `/chat/dm/conversations` | `{ peerId }` — suhbatni topadi yoki yaratadi |
| GET | `/chat/dm/conversations/:id/messages` | Tarix (sahifalab) |
| POST | `/chat/dm/upload` | Media yuklash → `{ url, svg, png, duration, size }` |

## Socket hodisalari

Chiquvchi (mijozdan):

| Hodisa | Ma'lumot |
|---|---|
| `dm.send` | `{ conversationId, content, contentType, key, svg?, png?, duration?, size? }` |
| `dm.typing` | `{ conversationId, isTyping, contentType? }` |
| `dm.read` | `{ conversationId, messageId? }` |

Kiruvchi (serverdan):

| Hodisa | Qachon |
|---|---|
| `dm.newMessage` | Yangi xabar (o'z xabaringiz tasdig'i ham) |
| `dm.typing` | Suhbatdosh yozmoqda |
| `dm.read` | Xabarlar o'qildi |
| `dm.presence` | Suhbatdosh onlayn/oflayn bo'ldi |

## Muhim jihatlar

**Idempotentlik.** Har bir xabarda mijoz bergan noyob `key` bo'ladi. Bir xil
kalit bilan qayta yuborilsa yangi xabar yaratilmaydi — tarmoq uzilib qayta
ulanganda dublikat chiqmaydi.

**Ulanish poygasi.** Socket autentifikatsiyasi `await` qilinmaydi: hodisa
ishlovchilari darhol ro'yxatga olinadi va ish boshlashdan oldin
`socket.authReady` ni kutadi. Aks holda ulanib darrov yuborilgan xabar
jimgina yo'qolardi.

**Cheklovlar.** Xabar uzunligi 8000 belgi, socket uchun token-bucket
(30 zaxira, sekundiga 5 tiklanadi), HTTP uchun `express-rate-limit`
(prod'da 15 daqiqada 2000 so'rov).

**Izolyatsiya.** Foydalanuvchi faqat o'z loyihasi ichida va faqat o'zi
ishtirok etadigan suhbatlarda ishlay oladi.

## Sinovdan o'tgan

53 ta avtomatik sinov: avtorizatsiya, idempotentlik, sahifalash,
o'qilmaganlar hisobi, ko'p qurilma sinxronizatsiyasi, qayta ulanish,
loyihalararo izolyatsiya, fayl nomida path traversal, unicode/RTL,
parallel yozish, presence.

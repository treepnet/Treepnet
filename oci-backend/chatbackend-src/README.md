# Messenger Chat Backend

TreepNet ilovasidagi chat uchun backend: 1:1 suhbatlar, real vaqtda xabar
almashish, presence va push (FCM).

Bu CRM chat backendidan **ajratib olingan** — faqat messenger uchun kerak
bo'lgan qismlar. Operator/admin paneli, staff boshqaruvi va CRM tiketlari
bu yerda yo'q. Media yuklash ham yo'q: chat faqat matn.

## Talablar

- Node.js 18+
- PostgreSQL 14+

## Ishga tushirish

```bash
npm install
cp .env.example .env.local     # qiymatlarni to'ldiring
npx prisma db push             # bo'sh bazada jadvallarni yaratadi
npm start
```

`http://localhost:3000/health` javob bersa (u bazani ham tekshiradi, baza
ishlamasa 503) — tayyor.

Server ishga tushganda sxemani o'zgartirmaydi. Ishlab turgan bazaga sxema
o'zgarishi qo'lda qo'yiladi: `prisma/manual/README.md`.

## Testlar va deploy

`npm test` — `test/` dagi testlar (baza kerak emas, hammasi o'rniga
qo'yilgan). Serverga faqat `deploy.sh` orqali: u git'dagi commit qilingan
holatni ko'chiradi, image'ni yig'adi, testlarni shu image ichida ishga
tushiradi va o'tsagina serverni almashtiradi.

## Autentifikatsiya

Alohida ro'yxatdan o'tish yo'q. Ilova Firebase ID tokenini yuboradi
(HTTP: `Authorization: Bearer ...`, socket: `auth.token`); foydalanuvchi
tokendagi `uid` bo'yicha aniqlanadi (`resolve_identity.js`). Tokensiz,
faqat `x-uuid` bilan kelgan so'rov `CHAT_AUTH_REQUIRED=true` da (prod)
rad etiladi.

Boshqa sarlavhalar:

| Sarlavha | Majburiy | Izoh |
|---|---|---|
| `x-app-key` | ha | Loyiha kaliti (`Project.apiKey`) |
| `x-app` | ha | Loyiha nomi |
| `x-device-id`, `x-device-name`, `x-device-type` | ha | Qurilma ma'lumoti |
| `x-lang` | ha | Til kodi (push matnlari shu tilda) |

Ism va avatar ilovadan olinmaydi: ular TreepNet profilidan keladi
(`profiles.js`). Foydalanuvchi birinchi murojaatda, faqat TreepNet akkaunti
bo'lsa, yaratiladi; yozuvi faqat biror maydon o'zgarganda yangilanadi.

## REST (`/chat/dm`)

| Metod | Yo'l | Vazifa |
|---|---|---|
| GET | `/me` | O'z profilim |
| GET | `/users?q=` | Yozish mumkin bo'lgan foydalanuvchilar |
| GET | `/conversations` | Suhbatlar ro'yxati (oxirgi xabar, o'qilmaganlar) |
| POST | `/conversations` | `{ peerId }` yoki `{ peerUuid }` — juftlik suhbatini topadi yoki yaratadi (har juftlikka bitta) |
| GET | `/conversations/:id/messages` | Tarix (sahifalab) |
| DELETE | `/conversations/:id` | Suhbatni faqat o'zim uchun tozalash (suhbatdoshda qoladi) |
| POST | `/device-token` | Push tokenini ro'yxatdan o'tkazish |
| DELETE | `/device-token` | Chiqishda tokenni olib tashlash |

## Socket hodisalari

Chiquvchi (mijozdan):

| Hodisa | Ma'lumot |
|---|---|
| `dm.send` | `{ conversationId, content, contentType, key, ... }` |
| `dm.edit` | Xabarni tahrirlash |
| `dm.delete` | Xabarni o'chirish |
| `dm.typing` | `{ conversationId, isTyping }` |
| `dm.read` | `{ conversationId, messageId? }` |

Kiruvchi (serverdan):

| Hodisa | Qachon |
|---|---|
| `dm.newMessage` | Yangi xabar (o'z xabaringiz tasdig'i ham) |
| `dm.messageEdited`, `dm.messageDeleted` | Xabar tahrirlandi / o'chirildi |
| `dm.typing` | Suhbatdosh yozmoqda |
| `dm.read` | Xabarlar o'qildi |
| `dm.presence` | Suhbatdosh onlayn/oflayn bo'ldi |
| `dm.authError` | Token yaroqsiz yoki akkaunt yo'q |

## Muhim jihatlar

**Idempotentlik.** Har bir xabarda mijoz bergan noyob `key` bo'ladi. Bir xil
kalit bilan qayta yuborilsa yangi xabar yaratilmaydi — tarmoq uzilib qayta
ulanganda dublikat chiqmaydi.

**Ulanish poygasi.** Socket autentifikatsiyasi `await` qilinmaydi: hodisa
ishlovchilari darhol ro'yxatga olinadi va ish boshlashdan oldin
`socket.authReady` ni kutadi. Aks holda ulanib darrov yuborilgan xabar
jimgina yo'qolardi.

**Cheklovlar.** Xabar uzunligi 8000 belgi; socket uchun token-bucket
(30 zaxira, sekundiga 5 tiklanadi); HTTP uchun 15 daqiqada manzil bo'yicha
10 000, foydalanuvchi bo'yicha 1000 so'rov.

**Izolyatsiya.** Foydalanuvchi faqat o'z loyihasi ichida va faqat o'zi
ishtirok etadigan suhbatlarda ishlay oladi; bloklangan juftlik suhbat
ocholmaydi.

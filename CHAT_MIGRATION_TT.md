# Texnik Topshiriq — Chat almashtirish: TreepNet custom chat → `messenger_chat` (self-hosted plugin + backend)

**Versiya:** 1.0  **Sana:** 2026-08-29  **Branch:** `oci-integration` (yangi `chat-integration` branch tavsiya etiladi)
**Manba:** 3 ta chuqur analiz (bizning chat + `messenger_chat` plugin + `messenger-chat-backend`) asosida.

---

## 1. Maqsad va doira

**Muammo:** TreepNet'ning hozirgi custom chati (PowerSync-asosli, offline-first) buggy — xabarlar ko'payganda yetib bormaydi, ishonchsiz.

**Maqsad:** Uni sizning o'z **self-hosted** yechimingiz bilan almashtirish:
- `messenger-chat-backend` (Node + Express + **Socket.IO** + Prisma/Postgres) — OCI'ga deploy
- `messenger_chat` (Flutter plugin, transport-agnostik chat UI) — ilovaga integratsiya
- Natija: **ishonchli real-time** chat, media qo'llab-quvvatlashi bilan, TreepNet'ga xos funksiyalar (shared post/story, reply, block) saqlangan holda.

**Doira ichida:** backend OCI deploy, plugin integratsiyasi, transport implementatsiyasi, TreepNet funksiyalarini pluginga qo'shish, eski chatni to'liq olib tashlash, push (FCM).

**Doiradan tashqari:** guruh chatlar, reaksiyalar, xabar qidiruvi (bizda ham yo'q), eski xabarlarni migratsiya qilish (sandbox data — tashlaymiz).

---

## 2. Arxitektura

Chat — **alohida mikroservis**, lekin bir OCI stack ichida (avvalgi servislar kabi):

```
OCI VM — docker-compose
├── caddy            → chat.treepnet.com (WebSocket + REST)  [YANGI marshrut]
├── postgres  ───────┬── treepnet DB   (app)
│                     └── chat DB       (Prisma: Project/User/Conversation/DirectMessage)  [YANGI]
├── chatbackend  ←── YANGI: Node + Socket.IO (Dockerfile authoring kerak)
├── chatredis    ←── YANGI (ixtiyoriy — presence/cache; yo'q bo'lsa ham ishlaydi)
├── postgrest, powersync, authservice, pushworker, deleteaccount  (mavjud)
```

**Identity (kalit nuqta):** chat backend header-auth ishlatadi (`x-uuid`). Biz `x-uuid = profiles.id (UUID = Firebase sub)` yuboramiz. Ya'ni:
- `x-uuid` = joriy foydalanuvchi profil UUID
- `x-app-key` = biz yaratadigan `Project.apiKey`
- `x-app` = `treepnet`, `x-device-name` = qurilma (majburiy)
- Chat backend `User` yozuvlari `x-uuid` bo'yicha avtomatik yaratiladi — alohida ro'yxatdan o'tish yo'q.

**Plugin ↔ backend:** plugin to'g'ridan-to'g'ri `chat.treepnet.com`'ga ulanadi (REST + Socket.IO), **PowerSync/PostgREST'dan mustaqil**. Feed/profil o'z yo'lida, chat o'z transportida.

**Media:**
- **Shared post/story/reel** → faqat **ID havola** (dublikat YO'Q — §7)
- **Kompozer media** (rasm/video/ovoz/fayl) → chat backend upload → **OCI Object Storage** (yoki boshda lokal volume)

---

## 3. JADVAL 1 — Pluginda MAVJUD funksiyalar (`messenger_chat` v1.0.8)

| # | Funksiya | Tafsilot |
|---|----------|----------|
| 1 | Matn xabar | Optimistik send, link preview (OG, any_link_preview) |
| 2 | ~~Rasm xabar~~ | ⏸️ **O'CHIRILADI** (`ChatFeatures(photo:false)`) — kod qoladi, tugma yashirinadi, kelajakda qayta yoqiladi |
| 3 | ~~Video xabar~~ | ⏸️ **O'CHIRILADI** (`ChatFeatures(video:false)`) |
| 4 | ~~Fayl/hujjat~~ | ⏸️ **O'CHIRILADI** (`ChatFeatures(file:false)`) |
| 5 | ~~Ovozli xabar~~ | ⏸️ **O'CHIRILADI** (`ChatFeatures(voice:false)`) |
| 6 | Typing indikator | Bubble + app-bar ("yozmoqda"/"ovoz yozmoqda"), 4s auto-reset, 2s debounce |
| 7 | O'qildi/ko'rildi (✓/✓✓) | Per-message status (clock/check/double-check/error), VisibilityDetector auto-mark-read |
| 8 | Unread count | List badge ("99+"), `onUnreadCount(cb)` stream |
| 9 | Emoji picker | emoji_picker_flutter, inline toggle |
| 10 | Link preview | OG metadata, 7-kun cache, tashqi ochish |
| 11 | Offline outbox | Hive-backed, reconnect'da auto-resend (text + media) |
| 12 | Presence | Online nuqta + "last seen" (app-bar + list avatar) |
| 13 | Pagination/history | Infinite scroll (chat 25, list 30), id/key dedupe |
| 14 | Sana ajratkichlari | Lokalizatsiyalangan "Bugun"/"Kecha" |
| 15 | Skeleton loading | skeletonizer + shimmer |
| 16 | Animatsiyalar | Bubble entrance, typing dots, mic pulse, ripple, scale |
| 17 | Scroll-to-bottom FAB | >200px scroll'da |
| 18 | Connection status | connecting/connected/error (app-bar) |
| 19 | Toast bildirishnomalar | Overlay, `controller.showToast` |
| 20 | Blur/glassmorphism | Toggle (`ChatFeatures(blurEffects:false)`) zaif GPU uchun |
| 21 | 2 ekran | `MessengerChatList` (inbox) + `MessengerChat` (suhbat) |
| 22 | Transport-agnostik | `ChatTransport` + `ChatListTransport` — biz implement qilamiz |
| 23 | Styling | `.light()`/`.dark()` + 5 style klass (app-bar/message/text-field/decoration/list) |
| 24 | Lokalizatsiya | uz / oz (kirill) / ru / en |
| 25 | Optimistik send + reconcile | `clientKey` bo'yicha (backend echo qaytarishi shart) |

**Xabar turlari (`ChatMessageKind`):** `text, photo, video, voice, file`.

> **⚠️ DOIRA QARORI (foydalanuvchi):** telefon xotirasidan media yuklash (rasm/video/fayl/ovoz) **KERAK EMAS** — faqat **matn + post/story share** yetarli. Media funksiyalari **`ChatFeatures(photo:false, video:false, voice:false, file:false)`** bilan **o'chiriladi** (kod olib tashlanmaydi — tugmalar yashirinadi, kelajakda `true` qilib qayta yoqiladi, 0 xavf). Natijada: (a) kompozerda faqat matn + emoji + post/story share; (b) backend `/upload` + ffmpeg + media-storage **hozircha ishlatilmaydi** (dormant qoladi) → **media-storage qarori (lokal/OCI) keyinga qoldiriladi**, hozir kerak emas.
**Backend qo'llaydi (Socket.IO):** `dm.send/typing/read` (client→server), `dm.newMessage/typing/read/presence` (server→client). REST: `/me, /users, /conversations (list+create), /conversations/:id/messages, /upload`.

---

## 4. JADVAL 2 — Bizning chatda MAVJUD funksiyalar (TreepNet)

| # | Funksiya | Tafsilot / holat |
|---|----------|------------------|
| 1 | 1:1 DM | `createChat` doim one-on-one |
| 2 | Matn xabar | **Markdown** (link) + emoji-only 42px enlarge |
| 3 | **Shared post karta** | `shared_post_id` (havola) → author+rasm+caption kartasi, deep-link |
| 4 | **Shared reel (video) karta** | inline video preview → post viewer |
| 5 | **Shared story karta** | `shared_story_id` (havola) → story viewer |
| 6 | URL/OG link preview | Kompozer 350ms debounce OG scrape |
| 7 | Typing indikator | Synced heartbeat (`typing_status`), 6s freshness, 2s throttle |
| 8 | O'qildi (✓/✓✓) | Synced `conversation_reads` watermark |
| 9 | Unread count | Per-chat + **bottom-nav badge** (local `chat_last_read` watermark) |
| 10 | **Reply / quote** | Swipe-to-reply + menu, quote chip (accent bar + thumb), tap→scroll+highlight |
| 11 | **Edit xabar** | `is_edited=1`, "edited" label |
| 12 | **Delete xabar** | Hard delete, tasdiqlash |
| 13 | **Delete suhbat** | Hard delete, long-press/menu, tasdiqlash |
| 14 | **Block gating (2 tomon)** | `blocked_users` → kompozer o'rniga "bloklangan" bar |
| 15 | Presence (online/last seen) | 45s heartbeat (`profiles.last_seen_at`), foreground-only |
| 16 | Optimistik send + retry | `failedIds` + retry snackbar |
| 17 | Offline-first | PowerSync local SQLite (eski xabarlar internetsiz ochiladi) |
| 18 | Pagination | Page size 10, DESC, `_shiftOffset` realtime-korreksiya |
| 19 | Sana ajratkichlari | `MessageDateTimeSeparator` |
| 20 | State persistence | HydratedBloc (xabarlar disk'da saqlanadi) |
| 21 | **"Type" tab** | Follow/suggested foydalanuvchilardan yangi chat boshlash |
| 22 | 7 kirish nuqtasi | inbox, type-tab, profil "Message", notifications, story reply, share-sheet, "+" |
| 23 | ~~Media kompozer~~ | ❌ **YO'Q** — faqat matn (rasm/video/ovoz kompozerda yo'q!) |
| 24 | ~~Push~~ | ❌ **YO'Q** (o'chirilgan) |
| — | Reaksiya / qidiruv / guruh | ❌ yo'q |

**Muhim texnik nozikliklar (regressiya bo'lmasin):**
- 2 xil read-tracking: lokal `chat_last_read` (unread badge) + synced `conversation_reads` (✓✓) — `messages.is_read` PowerSync'da round-trip qilmaydi.
- Barcha vaqtlar **naive local wall-clock** (TZ skew oldini olish).
- Attachments PowerSync'da **global** sync (parameter query JOIN qila olmaydi).

---

## 5. JADVAL 3 — Integratsiyadan keyin pluginga QO'SHILADIGAN funksiyalar

Bu — bizning chatga **parity** + yaxshilashlar. Har biri: backend + plugin + app tomonlari.

| # | Qo'shiladigan funksiya | Backend ishi | Plugin ishi | App ishi | Prioritet | Effort |
|---|------------------------|--------------|-------------|----------|:---:|:---:|
| 1 | **Shared post/reel/story kartalari** | Yangi `contentType='shared_post'\|'shared_story'`; `DirectMessage.refType`+`refId`(+cache: preview_url, caption) maydonlari; `dm.send` qabul qilsin | Custom message-kind + bubble renderer (post/story kartasi) + deep-link; `ChatMessageKind`'ga `sharedPost/sharedStory` qo'shish | Feed/story "ulashish" oqimlarini yangi chatga ulash; deep-link → post/story viewer | 🔴 | Yuqori (1-2 kun) |
| 2 | **Reply / quote** | `DirectMessage.replyToId` (FK); `dm.send`'da `replyToId`; DTO'da replied-message preview | Swipe-to-reply + menu; quote chip; tap→scroll+highlight | — | 🔴 | O'rta-yuqori (2 kun) |
| 3 | **Edit xabar** | `dm.edit` event; `content` update + `editedAt`/`isEdited`; server→client `dm.edited` | Edit menu + kompozer edit-mode; "edited" label; realtime update | — | 🟠 | O'rta (1 kun) |
| 4 | **Delete xabar** | `dm.delete` event; soft-delete (`deletedAt`) yoki hard; server→client `dm.deleted` | Delete menu; "deleted" placeholder; realtime remove | — | 🟠 | O'rta (1 kun) |
| 5 | **Delete suhbat** | `DELETE /conversations/:id` (participant-scoped); server→client `dm.conversationRemoved` | List'da remove; suhbat ekranidan chiqish | Long-press → tasdiqlash | 🟠 | Past (½ kun) |
| 6 | **Block gating (2 tomon)** | *Variant A:* app-darajasida (mavjud `blocked_users`) gate. *Variant B:* backend block table + send rad etish | Kompozer "read-only/bloklangan" holati (plugin hook kerak) | `isBlocked` tekshirish, chat ochishdan oldin gate | 🟠 | O'rta (1 kun) |
| 7 | **Unread → nav badge** | (mavjud unreadCount) | `onUnreadCount`/list transport | Bottom-nav Chat tab badge'iga ulash | 🟡 | Past (½ kun) |
| 8 | **"Type" tab** (yangi chat) | `POST /conversations {peerId}` (mavjud) | — | Follow/suggested (bizning social graph) → peer tanlash → conversation ochish | 🟡 | O'rta (1 kun) |
| 9 | **7 kirish nuqtasi** | — | — | profil "Message", notifications, story reply, share-sheet, inbox, "+", type-tab — hammasini yangi oqimga ulash | 🟡 | O'rta (1 kun) |
| 10 | **UI/dizayn moslash** | — | Style klasslar → TreepNet dizayni (qora fon, kulrang bubble, ✓✓, ikonlar, `blurEffects` toggle) | Ikon SVG'larni ta'minlash | 🟡 | O'rta (1-2 kun) |
| 11 | **Markdown/link matn + emoji-enlarge** | — | Matn render (Markdown link + emoji-only enlarge) | — | 🟢 | Past (½ kun) |
| 12 | **Push (FCM)** *(bonus — bizda yo'q edi)* | Yangi xabarda push_outbox'ga yozish yoki to'g'ridan-to'g'ri FCM; deep-link chatga | Push tap → chat ochish (background hook mavjud) | Push routing | 🟢 | O'rta (1 kun) |

**Plugin BEPUL beradigan (bizda yo'q edi — bonus, qo'shish shart emas):** haqiqiy media xabarlar (rasm/video/ovoz/fayl kompozerdan), emoji picker, ovoz yozish, skeleton/animatsiyalar, ishonchli Socket.IO real-time.

---

## 6. Backend deploy rejasi (OCI)

1. **Dockerfile authoring** — repo'da yo'q. Node 20 (glibc, Alpine emas — `ffmpeg-static` uchun), `prisma generate`, entrypoint: `prisma db push` → `node index.js`.
2. **docker-compose'ga qo'shish** — `chatbackend` servis: `DATABASE_URL` → OCI Postgres `chat` DB, `CORS_ORIGIN`, `REDIS_URL` (ixtiyoriy `chatredis`), `PORT=3000`, `UPLOAD_DIR` volume.
3. **`chat` DB yaratish** — OCI Postgres'da yangi database + Prisma role.
4. **Caddy marshruti** — `chat.treepnet.com` → `chatbackend:3000`, **WebSocket upgrade** header'lari (Socket.IO uchun), `x-forwarded-for` uzatish. DNS A-record.
5. **Project seed** — admin endpoint yo'q; `Project(name='treepnet', apiKey=<random>)` qatorini qo'lda SQL/Prisma bilan qo'shish (aks holda har so'rov `403 Invalid Project`).
6. **Media storage** — boshda lokal `uploads/` volume; keyin `media_service.js`'ni OCI Object Storage'ga moslash (app media kabi). URL'lar absolute bo'lishi shart.
7. **FCM push** (gap #12) — backend'ga `firebase-admin` qo'shish yoki `push_outbox`'ga yozib mavjud pushworker'dan foydalanish.
8. **Single instance** — Socket.IO Redis-adapter yo'q; presence in-process. Bitta instansda ishlatamiz (scaling kerak bo'lsa `@socket.io/redis-adapter`).

---

## 7. Media / dublikat siyosati (kritik)

| Holat | Yuklanadimi? | Qanday |
|-------|:---:|--------|
| **Post/story ulashish/forward** | ❌ **YO'Q** | Xabar faqat `refId` (post/story UUID) saqlaydi; karta postning **mavjud OCI URL**'ini ishlatadi. 1000 forward = 0 yangi media |
| **Kompozer media** (rasm/video/ovoz/fayl) | ⏸️ **HOZIRCHA O'CHIQ** | `ChatFeatures(...:false)` bilan yashirilgan — upload bo'lmaydi. Kelajakda yoqilsa: har fayl 1 marta upload (normal) |
| *(kelajak)* Kompozer dedup | — | Media qayta yoqilganda: content-hash bo'yicha bir xil fayl → o'sha URL |

**Qoida:** shared TreepNet kontenti — **hech qachon nusxa emas, faqat havola** (bizning hozirgi chat kabi).

---

## 8. Eski chatni olib tashlash

- `lib/chats/` (butun daraxt), `packages/chats_repository/`
- `database_client.dart` chat metodlari (§interface 422–503, impl 2583–3601)
- `sync-config.yaml`: `user_conversations`, `global_attachments` (chat qismi), `blocked_users` buketlari (block app'da qolsa)
- Postgres/PowerSync schema: `conversations, messages, participants, typing_status, conversation_reads, chat_last_read, attachments` (chat qismi)
- Nav badge, presence, entry point'larni yangi pluginga qayta ulash (avval yangi ishlab, keyin eski olib tashlanadi)

---

## 9. Backend data-model qo'shimchalari (Prisma)

`DirectMessage`'ga: `replyToId Int?` (self-relation), `editedAt DateTime?`, `deletedAt DateTime?`, `refType String?` (`post`/`story`), `refId String?` (UUID), `refPreview Json?` (caption/thumb cache). `contentType`'ga `shared_post`/`shared_story` qiymatlari. Block uchun (Variant B) `Block` model.

---

## 10. Bosqichma-bosqich reja (phasing)

| Bosqich | Mazmun | Taxminiy |
|---------|--------|----------|
| **0. Tayyorgarlik** | Backend Dockerfile + OCI deploy + `chat` DB + Caddy + Project seed + health test | ~1-2 kun |
| **1. MVP** | Plugin qo'shish (dep konflikt yechish) + `ChatTransport`/`ChatListTransport` + inbox + suhbat + entry point'lar (asosiy) + eski chatni olib tashlash. Ishlaydigan real-time chat: matn, media, typing, read, unread, presence | ~1 hafta |
| **2. TreepNet parity** | Shared post/story kartalari (havola!) + reply + block gating + "Type" tab + nav badge | ~1 hafta |
| **3. Polish** | Edit/delete + delete-conversation + push (FCM) + UI/dizayn moslash + Markdown | ~½ hafta |

**Jami: ~2.5-3 hafta** to'liq parity. MVP (1-bosqich) tugagach buggy chat o'rniga ishonchli chat bo'ladi.

---

## 11. Xavflar va yumshatish

| Xavf | Yumshatish |
|------|-----------|
| **Dependency konfliktlari** (#1 amaliy) — plugin ~30 paket (just_audio, record, video_player, flick_video_player, permission_handler, image_picker, file_picker...) app paketlari bilan | `flutter pub get` bilan bosqichma-bosqich yechish; kerak bo'lsa versiya override; git-dep sifatida fork |
| **Shared kontent plugin modeliga sig'maydi** | `ChatMessageKind`'ga sharedPost/sharedStory qo'shish + custom renderer hook (plugin fork kerak bo'lishi mumkin) |
| **Reply/edit/delete backend'da yo'q** | Prisma schema + socket event'lar qo'shish (fork) |
| **Block — 2 tizim** | Block'ni app'da (`blocked_users`) ushlash, plugin atrofida gate |
| **Push yo'q** | FCM qo'shish (backend → push_outbox/pushworker) |
| **Media local** | OCI volume yoki OCI Object Storage adapteri |
| **Plugin ikon SVG'lari vestigial** | App o'z ikonlarini beradi (plugin faqat 5 ikon ship qiladi) |
| **`clientKey` echo** | Backend `dm.newMessage`'da `key` qaytaradi (mavjud) — optimistik dedup uchun shart |
| **OCI VM resursi** | Node+Socket.IO yengil; Redis ixtiyoriy; ffmpeg + media yuklamani kuzatish |
| **Offline o'qish yo'qoladi** | PowerSync o'rniga socket — eski xabarlar internet talab qiladi (chat uchun normal) |
| **Plugin/backend fork** | Ikkalasi ham sizniki — o'zgartirishlar o'z repolaringizga push qilinadi |

---

## 12. Qabul mezonlari (Definition of Done)

- [ ] Backend OCI'da jonli (`chat.treepnet.com/health` → ok), WebSocket ishlaydi
- [ ] Ikki qurilma o'rtasida real-time: yuborish/qabul, typing, ✓✓, presence — **ishonchli** (eski bug yo'q)
- [ ] Kompozer media (rasm/video/ovoz/fayl) `ChatFeatures` bilan o'chirilgan (tugmalar yashirin); matn + emoji + post/story share ishlaydi
- [ ] Shared post/story ulashish → karta + deep-link, **media dublikat yo'q** (§7)
- [ ] Reply/edit/delete/delete-conversation ishlaydi
- [ ] Block: ikki tomonlama gate
- [ ] Unread nav badge + "Type" tab + 7 entry point
- [ ] Push: ilova yopiqda xabar keladi → tap → chat ochiladi
- [ ] Eski chat to'liq olib tashlangan (kod + jadval + sync-rule)
- [ ] `x-uuid` = profil UUID (Firebase sub) — identity mos

---

## 13. Men qila olaman / sizdan kerak

**Men:** backend OCI deploy + Dockerfile, plugin integratsiyasi + dep konflikt, transport, TreepNet funksiyalarini qo'shish (plugin/backend fork), eski chatni olib tashlash, FCM push, UI moslash.

**Sizdan:** ① qaror (block: app yoki backend). *(Media-storage qarori endi kerak emas — kompozer media o'chirilgan, upload yo'q.)* ② qurilmada test (2 qurilma bilan real-time), ③ plugin/backend repolaringizga o'zgarish push qilish ruxsati.

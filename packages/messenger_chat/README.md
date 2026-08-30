# messenger_chat

Messenger ilovalar uchun tayyor **1:1 chat ekrani** — Flutter plagini.

Matn, rasm, video, hujjat va ovozli xabarlar; "yozmoqda" ko'rsatkichi, o'qildi
statusi, oflayn navbat (outbox) va emoji tanlagich — hammasi ichida.

**Plagin tarmoq bilan ishlamaydi.** U qanday backend ishlatishingizni bilmaydi
va bilishi ham shart emas: siz [`ChatTransport`](lib/api/chat_transport.dart)
ni amalga oshirasiz, plagin faqat UI va lokal holatni boshqaradi. Shu sababli
uni REST, WebSocket, Firebase yoki boshqa har qanday transport bilan ishlatish
mumkin.

## Ulash

```yaml
dependencies:
  messenger_chat:
    path: ../Messenger_Chat_Plugin
```

## Foydalanish

### 1. Transportni yozing

Ilovangizning backendi bilan ishlaydigan yagona joy:

```dart
class MyTransport implements ChatTransport {
  @override
  Future<void> connect() async { /* socketni ulang */ }

  @override
  Future<ChatHistoryPage> loadHistory({required int page, required int size}) async {
    final res = await api.messages(conversationId, page: page, size: size);
    return ChatHistoryPage(
      messages: res.items.map((e) => ChatIncomingMessage(
        id: e.id,
        senderId: e.senderId,
        kind: ChatMessageKind.text,
        content: e.text,
        sentAt: e.createdAt,
        isRead: e.isRead,
      )).toList(),
      hasMore: res.hasMore,
    );
  }

  @override
  Future<void> send(ChatOutgoingMessage message) => api.send(message);

  // uploadAttachment, sendTyping, markRead, events, dispose ...
}
```

Media manzillari **to'liq** bo'lishi kerak (`https://...`). Agar backend nisbiy
yo'l qaytarsa, uni transport ichida to'ldiring — namunada shunday qilingan:
[`example/lib/rest_socket_transport.dart`](example/lib/rest_socket_transport.dart).

### 2. Plaginni tayyorlang

```dart
await MessengerChat.init(
  transport: MyTransport(),
  me: ChatUser(id: currentUser.id, name: currentUser.name),
  lang: ChatLanguage.uzbek,
);
```

`me.id` xabarning qaysi tomonda chizilishini belgilaydi: `senderId == me.id`
bo'lsa — o'ngda, aks holda chapda.

### 3. Ekranni oching

```dart
Scaffold(
  appBar: MessengerChat.appBar(myAppBarStyle),
  body: MessengerChat.light(
    peer: ChatUser(id: peer.id, name: peer.name, avatarUrl: peer.photo),
    lang: ChatLanguage.uzbek,
  ),
);
```

Ekran yopilganda:

```dart
await MessengerChat.release();
```

## Xabar turlarini cheklash

```dart
await MessengerChat.init(
  transport: transport,
  me: me,
  features: const ChatFeatures(voice: false, video: false),
);
```

`ChatFeatures.textOnly()` — faqat matn.

## Suhbatlar ro'yxati (chat list)

Ro'yxatning o'z shartnomasi bor — [`ChatListTransport`](lib/api/chat_list_transport.dart):

```dart
class MyListTransport implements ChatListTransport {
  @override
  Future<void> connect() async { /* socketni ulang */ }

  @override
  Future<ChatConversationPage> loadConversations({required int page, required int size}) async {
    final res = await api.conversations(page: page, size: size);
    return ChatConversationPage(
      conversations: res.items.map((e) => ChatConversation(
        id: e.id,
        peer: ChatUser(id: e.peerId, name: e.peerName, avatarUrl: e.peerAvatar),
        lastMessage: e.lastText,
        lastMessageAt: e.lastAt,
        unreadCount: e.unread,
      )).toList(),
      hasMore: res.hasMore,
    );
  }

  @override
  Stream<ChatListEvent> get events => _events.stream;

  @override
  Future<void> dispose() async { /* ... */ }
}
```

Ekranda:

```dart
MessengerChatList(
  transport: myListTransport,
  onConversationTap: (c) => Navigator.push(...),
)
```

Vidjet hodisalarni o'zi qo'llaydi va **o'zi tartiblaydi**: yangi xabar kelgan
suhbat yuqoriga chiqadi, qadalganlar doim tepada. Sahifalash, pull-to-refresh,
o'qilmaganlar nishoni, onlayn nuqtasi — hammasi ichida.

| Hodisa | Qachon |
|---|---|
| `ChatConversationUpserted` | yangi xabar, o'qildi, nom/avatar o'zgardi |
| `ChatConversationRemoved` | suhbat o'chirildi |
| `ChatPeerPresenceChanged` | suhbatdosh onlayn/oflayn bo'ldi |
| `ChatListConnectionChanged` | ulanish holati |

Ro'yxat va ochilgan suhbat **bitta socketdan** foydalanishi mumkin — shunda
suhbat ochiq turganda ham ro'yxat yangilanib turadi. Namunada shunday qilingan
(`DmApi` ikkalasiga umumiy).

## Unumdorlik

Fon xiralashtirish (`BackdropFilter`) chiroyli, lekin eski GPU larda qimmat:
har bir kadrda save-layer + blur o'tishi bajariladi.

Samsung A40 (2019) da o'lchandi — tinch turgan ekranda ham raster **43 ms**
edi (~23 fps), blur o'chirilganda **16 ms** ga tushdi:

```dart
features: const ChatFeatures(blurEffects: false),
```

O'chirilganda panel va app bar avtomatik noshaffof bo'ladi, shuning uchun
orqadagi xabarlar ko'rinib qolmaydi.

Xabarlar soni to'siq emas: ro'yxat lazy, 300 ta xabarda ham kadr qurish vaqti
25 ta xabardagidan farq qilmadi (1.6–2.1 ms).

## Namuna

`example/` ichida to'liq ishlaydigan ilova bor:

```bash
cd example
flutter run --dart-define=CHAT_BASE_URL=http://127.0.0.1:3000
```

## Arxitektura

```
Ilova
  ├── ChatTransport      ← bitta suhbat uchun (siz yozasiz)
  └── ChatListTransport  ← suhbatlar ro'yxati uchun (siz yozasiz)
        ↕
  messenger_chat
        ├── MessengerChat      (suhbat ekrani)
        ├── MessengerChatList  (suhbatlar ro'yxati)
        ├── Cubit (holat)
        └── Outbox (oflayn navbat, Hive)
```

Plagin ichida `dio`, `socket_io_client` yoki boshqa tarmoq kodi **yo'q**.

## Talablar

- Flutter >= 3.3.0, Dart SDK ^3.8.1
- Android `minSdk` 23
- Mikrofon ruxsati (ovozli xabar uchun): `RECORD_AUDIO`

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:messenger_chat/messenger_chat.dart';

import 'dm_api.dart';
import 'dm_transports.dart';
import 'new_chat_screen.dart';

/// Backend manzili build vaqtida beriladi:
///   flutter run --dart-define=CHAT_BASE_URL=http://127.0.0.1:3000
const String kChatBaseUrl = String.fromEnvironment(
  'CHAT_BASE_URL',
  defaultValue: 'http://192.168.0.10:3000',
);

/// Shu qurilmadagi foydalanuvchi. Odatda ilovaning o'z sessiyasidan olinadi.
const String kMyUuid = String.fromEnvironment(
  'CHAT_UUID',
  defaultValue: '8ed5e103-e88b-43fd-bbdc-b5d6b70d17cb',
);

const String kMyName = String.fromEnvironment(
  'CHAT_NAME',
  defaultValue: 'Men',
);

const String kAppName = 'messanger';
const String kApiKey = 'messenger-api-key';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Messenger Chat namunasi',
    debugShowCheckedModeBanner: false,
    home: const ChatListScreen(),
  );
}

/// Boshlang'ich ekran - suhbatlar ro'yxati.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  DmApi? _api;
  DmListTransport? _listTransport;

  /// Serverdagi son ko'rinishidagi identifikatorimiz - `senderId` bilan
  /// solishtirish uchun kerak.
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _listTransport?.dispose();
    super.dispose();
  }

  Object? _bootstrapError;

  Future<void> _bootstrap() async {
    try {
      await _connect();
    } catch (e) {
      if (mounted) setState(() => _bootstrapError = e);
    }
  }

  Future<void> _connect() async {
    final deviceId = await MessengerChat.getDeviceId();
    final api = DmApi(
      baseUrl: kChatBaseUrl,
      myUuid: kMyUuid,
      appName: kAppName,
      apiKey: kApiKey,
      deviceId: deviceId,
      deviceName: kMyName,
    );

    // Serverdagi identifikatorimizni olamiz - xabar kimdan kelganini shu
    // bilan aniqlaymiz.
    final me = await api.dio.get<Map<String, dynamic>>('/chat/dm/me');
    final myUserId = me.data?['id']?.toString() ?? '';

    if (!mounted) return;
    setState(() {
      _api = api;
      _myUserId = myUserId;
      _listTransport = DmListTransport(api: api, myUserId: myUserId);
    });
  }

  Future<void> _openChat(ChatConversation conversation) =>
      _openConversation(id: conversation.id, peer: conversation.peer);

  /// Yangi suhbat boshlash ekranini ochadi.
  Future<void> _startNewChat() async {
    final api = _api;
    if (api == null) return;

    final result = await Navigator.of(context).push<({String id, ChatUser peer})>(
      MaterialPageRoute(builder: (_) => NewChatScreen(api: api)),
    );

    if (result == null || !mounted) return;
    await _openConversation(id: result.id, peer: result.peer);
  }

  Future<void> _openConversation({
    required String id,
    required ChatUser peer,
  }) async {
    final api = _api;
    if (api == null) return;

    final transport = DmChatTransport(
      api: api,
      conversationId: id,
      myUserId: _myUserId ?? '',
    );

    await MessengerChat.init(
      transport: transport,
      me: ChatUser(id: _myUserId ?? '', name: kMyName),
      lang: ChatLanguage.uzbekCyrillic,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(peer: peer),
      ),
    );

    // Suhbat yopilganda plagin resurslarini to'liq bo'shatamiz.
    await MessengerChat.release();
  }

  @override
  Widget build(BuildContext context) {
    final transport = _listTransport;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Suhbatlar'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _api == null
          ? null
          : FloatingActionButton(
              onPressed: _startNewChat,
              backgroundColor: const Color(0xff1064FF),
              child: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
      body: _bootstrapError != null
          ? _ErrorView(
              error: _bootstrapError!,
              onRetry: () {
                setState(() => _bootstrapError = null);
                unawaited(_bootstrap());
              },
            )
          : transport == null
          ? const Center(child: CircularProgressIndicator())
          : MessengerChatList(
              transport: transport,
              onConversationTap: _openChat,
              lang: ChatLanguage.uzbekCyrillic,
            ),
    );
  }
}

/// Suhbat ekrani.
class ChatScreen extends StatelessWidget {
  const ChatScreen({required this.peer, super.key});

  final ChatUser peer;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffEAF3FD),
    resizeToAvoidBottomInset: false,
    appBar: MessengerChat.appBar(
      const ChatAppBarStyle(
        backgroundColor: Colors.white,
        profileBackgroundColor: Color(0xff1064FF),
        profileIconColor: Colors.white,
        profileIconSvgPath: 'assets/icons/support.svg',
        backIconSvgPath: 'assets/icons/arrow-left.svg',
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        statusTextStyle: TextStyle(color: Color(0xff6B7280), fontSize: 13),
      ),
      peer: peer,
    ),
    body: MessengerChat.light(peer: peer, lang: ChatLanguage.uzbekCyrillic),
  );
}


/// Ulanish xatosi - jimgina aylanaverish o'rniga sababni ko'rsatamiz.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Backendga ulanib bo'lmadi"),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xff6B7280), fontSize: 12),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/open_chat.dart';

/// The chat inbox (conversation list), backed by the messenger_chat plugin.
///
/// Renders the shared [ChatSession] list transport; each row opens its thread.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  static const _background = Color(0xff191919);

  static const _listStyle = ChatListStyle(
    backgroundColor: _background,
    avatarBackgroundColor: Color(0xff414141),
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    previewTextStyle: TextStyle(color: Color(0xff9AA6A6), fontSize: 14),
    timeTextStyle: TextStyle(color: Color(0xff687575), fontSize: 12),
    unreadBadgeColor: Color(0xff728FCE),
    readIconColor: Color(0xff728FCE),
    unreadIconColor: Color(0xff687575),
    onlineColor: Color(0xff4CAF50),
    dividerColor: Color(0xff2A2A2A),
  );

  Future<void>? _bootstrap;

  @override
  void initState() {
    super.initState();
    _bootstrap = _start();
  }

  Future<void> _start() async {
    final me = context.read<AppBloc>().state.user;
    await ChatSession.instance.ensureStarted(
      myUuid: me.id,
      myName: me.displayFullName,
      myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
    );
  }

  void _retry() => setState(() => _bootstrap = _start());

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'Xabarlar',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    body: FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xff728FCE)),
          );
        }
        if (snapshot.hasError || !ChatSession.instance.isStarted) {
          return _ErrorView(onRetry: _retry);
        }
        return MessengerChatList(
          transport: ChatSession.instance.listTransport,
          lang: chatLanguageFor(context),
          style: _listStyle,
          onConversationTap: (conversation) => openConversationScreen(
            context,
            conversationId: conversation.id,
            peer: conversation.peer,
          ),
        );
      },
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Suhbatlarni yuklab bo‘lmadi',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Qayta urinish')),
      ],
    ),
  );
}

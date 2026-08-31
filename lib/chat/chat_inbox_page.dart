import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/chat_theme.dart';
import 'package:treepnet/chat/new_chat_screen.dart';
import 'package:treepnet/chat/open_chat.dart';
import 'package:user_repository/user_repository.dart';

/// The chat inbox (conversation list), backed by the messenger_chat plugin.
///
/// Renders the shared [ChatSession] list transport; each row opens its thread.
class ChatInboxPage extends StatefulWidget {
  const ChatInboxPage({super.key});

  @override
  State<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends State<ChatInboxPage> {
  static const _background = ChatTheme.background;
  static const _listStyle = ChatTheme.listStyle;

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

  /// Opens people search; on selection, opens the chat with that user.
  Future<void> _newChat() async {
    final user = await Navigator.of(context, rootNavigator: true).push<User>(
      MaterialPageRoute(builder: (_) => const NewChatScreen()),
    );
    if (user == null || !mounted) return;
    await openChat(
      context,
      peerUuid: user.id,
      peerName: user.displayFullName,
      peerAvatarUrl: user.hasAvatar ? user.avatarUrl : null,
    );
  }

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
      actions: [
        IconButton(
          onPressed: _newChat,
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          tooltip: 'Yangi suhbat',
        ),
      ],
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

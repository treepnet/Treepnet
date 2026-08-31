import 'package:flutter/material.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/chat/chat_theme.dart';

/// A single 1:1 conversation, styled with the app's chat design tokens
/// ([ChatTheme]).
///
/// [MessengerChat.init] must already have been called (see `openChat`) — this
/// widget only draws the configured conversation.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({required this.peer, required this.lang, super.key});

  final ChatUser peer;
  final ChatLanguage lang;

  @override
  Widget build(BuildContext context) => MessengerChat(
    peer: peer,
    lang: lang,
    chatAppBarStyle: ChatTheme.appBarStyle,
    chatDecoration: ChatTheme.decoration,
    messageStyle: ChatTheme.messageStyle,
    chatTextFieldStyle: ChatTheme.textFieldStyle,
  );
}

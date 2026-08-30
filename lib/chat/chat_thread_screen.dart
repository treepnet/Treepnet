import 'package:flutter/material.dart';
import 'package:messenger_chat/messenger_chat.dart';

/// A single 1:1 conversation, rendered by the messenger_chat plugin.
///
/// [MessengerChat.init] must already have been called (see `openChat`) — this
/// widget only draws the configured conversation.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({required this.peer, required this.lang, super.key});

  final ChatUser peer;
  final ChatLanguage lang;

  /// App-bar styling tuned to the app's dark chat palette. The two svg-path
  /// fields are required by [ChatAppBarStyle] but the app bar renders an icon
  /// font + network avatar instead, so empty placeholders are fine.
  static const _appBarStyle = ChatAppBarStyle(
    backgroundColor: Color(0xff191919),
    profileBackgroundColor: Color(0xff414141),
    profileIconColor: Colors.white,
    backIconSvgColor: Colors.white,
    profileIconSvgPath: '',
    backIconSvgPath: '',
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    statusTextStyle: TextStyle(color: Color(0xff687575), fontSize: 12),
    labelTextStyle: TextStyle(color: Color(0xff687575), fontSize: 12),
    typingTextColor: Color(0xff728FCE),
    onlineColor: Color(0xff4CAF50),
    offlineColor: Color(0xff687575),
  );

  @override
  Widget build(BuildContext context) => MessengerChat.dark(
    peer: peer,
    lang: lang,
    chatAppBarStyle: _appBarStyle,
  );
}

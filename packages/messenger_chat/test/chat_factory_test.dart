import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_chat/messenger_chat.dart';

void main() {
  test('MessengerChat.light returns preset styles', () {
    final widget = MessengerChat.light(
      peer: const ChatUser(id: 'peer-1', name: 'Aziz'),
      lang: ChatLanguage.russian,
    );
    expect(widget.messageStyle.fileIconColor, const Color(0xff1064FF));
    expect(widget.chatDecoration.backgroundColor, const Color(0xffEAF3FD));
    expect(widget.chatTextFieldStyle.sendIconColor, Colors.white);
  });

  test('MessengerChat.dark returns preset styles', () {
    final widget = MessengerChat.dark(
      peer: const ChatUser(id: 'peer-1', name: 'Aziz'),
      lang: ChatLanguage.russian,
    );
    expect(widget.messageStyle.adminMessageBackgroundColor, const Color(0xff1F2937));
    expect(widget.chatDecoration.backgroundColor, const Color(0xff0F172A));
    expect(widget.chatTextFieldStyle.sendBackgroundColor, const Color(0xff2563EB));
  });
}

import 'package:flutter/material.dart';
import 'package:messenger_chat/messenger_chat.dart';

/// TreepNet chat design tokens, applied to the messenger_chat plugin so it
/// matches the rest of the app (see the `treepnet-chat-ui-design` reference).
///
/// Key look: flat #191919 background, BOTH message bubbles flat grey #414141
/// (no blue, no gradient), white 'Source Sans 3' text, #687575 secondary,
/// #728FCE accent, blur disabled.
abstract final class ChatTheme {
  static const background = Color(0xff191919);
  static const bubble = Color(0xff414141);
  static const secondary = Color(0xff687575);
  static const accent = Color(0xff728FCE);
  static const online = Color(0xff2FFFA4);
  static const divider = Color(0xff2A2A2A);

  /// Fonts live in the app_ui package; the package-qualified family always
  /// resolves app-wide.
  static const fontFamily = 'packages/app_ui/Source Sans 3';

  static const _text = TextStyle(
    fontFamily: fontFamily,
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Message types are disabled (text only) and blur is off for the app's flat
  /// look + perf.
  static const features = ChatFeatures(
    photo: false,
    video: false,
    voice: false,
    file: false,
    blurEffects: false,
  );

  static const messageStyle = ChatMessageStyle(
    clientMessageTextStyle: _text,
    adminMessageTextStyle: _text,
    clientMessageTimeTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 11,
    ),
    adminMessageTimeTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 11,
    ),
    dateSeparatorTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
    // Flat grey on BOTH sides — the app's chat has no coloured outgoing bubble.
    adminMessageBackgroundColor: bubble,
    clientMessageBackgroundColor: bubble,
    adminProfileBackgroundColor: bubble,
    readIconColor: Colors.white,
    adminAuthorTextColor: accent,
    fileIconColor: accent,
    clientAudioPlayIconColor: Colors.white,
    adminAudioPlayIconColor: accent,
    clientAudioWaveColor: Colors.white,
    adminAudioWaveColor: accent,
    adminProfileIconSvg: '',
    fileIconSvg: '',
  );

  static final decoration = ChatDecoration(backgroundColor: background);

  static const textFieldStyle = ChatTextFieldStyle(
    sendIconPath: '',
    closeIconPath: '',
    microphoneIconPath: '',
    attachmentIconPath: '',
    attachmentIconColor: secondary,
    inputFillColor: bubble,
    inputBackgroundColor: Colors.transparent,
    inputCursorColor: Colors.white,
    sendBackgroundColor: accent,
    sendIconColor: Colors.white,
    closeIconColor: Colors.white,
    enabledBorderColor: Colors.transparent,
    focusedBorderColor: Colors.transparent,
    microphoneBackgroundColor: accent,
    microphoneIconColor: Colors.white,
    inputHintTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 16,
    ),
    inputTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 16,
    ),
  );

  static const appBarStyle = ChatAppBarStyle(
    backgroundColor: background,
    profileBackgroundColor: bubble,
    profileIconColor: Colors.white,
    backIconSvgColor: Colors.white,
    profileIconSvgPath: '',
    backIconSvgPath: '',
    titleTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    statusTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 12,
    ),
    labelTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 12,
    ),
    typingTextColor: accent,
    onlineColor: online,
    offlineColor: secondary,
  );

  static const listStyle = ChatListStyle(
    backgroundColor: background,
    avatarBackgroundColor: bubble,
    avatarTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    previewTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 14,
    ),
    timeTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: secondary,
      fontSize: 12,
    ),
    unreadBadgeColor: accent,
    unreadBadgeTextStyle: TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    ),
    readIconColor: accent,
    unreadIconColor: secondary,
    onlineColor: online,
    dividerColor: divider,
  );
}

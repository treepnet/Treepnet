import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/backend/dm_transports.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/chat_thread_screen.dart';
import 'package:treepnet/chat/shared_message_card.dart';
import 'package:user_repository/user_repository.dart';

/// Whether either side has blocked the other — used to gate messaging
/// app-side (the chat backend doesn't know about blocks). Reads the current
/// value of the reactive `blocked_users` streams.
Future<bool> _blockedEitherWay(
  BuildContext context, {
  required String meId,
  required String peerUuid,
}) async {
  final repo = context.read<UserRepository>();
  final results = await Future.wait([
    repo.isBlocked(userId: meId, otherUserId: peerUuid).first,
    repo.isBlocked(userId: peerUuid, otherUserId: meId).first,
  ]);
  return results.any((blocked) => blocked);
}

/// Maps the app's current locale to the plugin's language enum.
ChatLanguage chatLanguageFor(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return switch (code) {
    'ru' => ChatLanguage.russian,
    'en' => ChatLanguage.english,
    'oz' => ChatLanguage.uzbekCyrillic,
    _ => ChatLanguage.uzbek,
  };
}

/// Opens (or creates) the 1:1 conversation with the given peer and pushes the
/// chat thread full-screen. The single entry point every "message this user"
/// call site funnels through.
///
/// [peerUuid] is the peer's `profiles.id`; [peerName]/[peerAvatarUrl] seed the
/// peer's backend row when they've never opened chat (cold-start).
Future<void> openChat(
  BuildContext context, {
  required String peerUuid,
  required String peerName,
  String? peerAvatarUrl,
}) async {
  final me = context.read<AppBloc>().state.user;
  if (peerUuid.isEmpty || me.isAnonymous || peerUuid == me.id) return;

  final session = ChatSession.instance;
  final lang = chatLanguageFor(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  // App-level block gate: you can't message someone you blocked, or who
  // blocked you.
  if (await _blockedEitherWay(context, meId: me.id, peerUuid: peerUuid)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Bu foydalanuvchi bilan yozishib bo‘lmaydi')),
    );
    return;
  }

  ({String conversationId, ChatUser peer}) opened;
  try {
    await session.ensureStarted(
      myUuid: me.id,
      myName: me.displayFullName,
      myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
    );
    opened = await session.openConversation(
      peerUuid: peerUuid,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Suhbatni ochib bo‘lmadi')),
    );
    return;
  }

  await _pushThread(
    navigator,
    conversationId: opened.conversationId,
    peer: opened.peer,
    lang: lang,
  );
}

/// Sends a one-off text message to a user (share post/story, story reply)
/// through the new backend, without opening the thread. Returns whether it was
/// attempted; throws on network failure so callers can show their own error.
Future<bool> shareTextToUser(
  BuildContext context, {
  required String peerUuid,
  required String peerName,
  required String text,
  String? peerAvatarUrl,
}) async {
  final me = context.read<AppBloc>().state.user;
  if (me.isAnonymous || peerUuid.isEmpty || peerUuid == me.id) return false;
  if (await _blockedEitherWay(context, meId: me.id, peerUuid: peerUuid)) {
    return false;
  }

  final session = ChatSession.instance;
  await session.ensureStarted(
    myUuid: me.id,
    myName: me.displayFullName,
    myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
  );
  await session.sendText(
    peerUuid: peerUuid,
    peerName: peerName,
    peerAvatarUrl: peerAvatarUrl,
    text: text,
  );
  return true;
}

/// Opens a conversation the inbox already resolved (id + peer known), skipping
/// the create/find round-trip. Still applies the block gate: the peer's app
/// uuid comes from the list transport (the plugin's [ChatUser] only carries the
/// backend id).
Future<void> openConversationScreen(
  BuildContext context, {
  required String conversationId,
  required ChatUser peer,
}) async {
  final session = ChatSession.instance;
  final peerUuid = session.isStarted
      ? session.listTransport.peerUuidOf(conversationId)
      : null;

  if (peerUuid != null && peerUuid.isNotEmpty) {
    final me = context.read<AppBloc>().state.user;
    final messenger = ScaffoldMessenger.of(context);
    if (!me.isAnonymous &&
        await _blockedEitherWay(context, meId: me.id, peerUuid: peerUuid)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bu foydalanuvchi bilan yozishib bo‘lmaydi'),
        ),
      );
      return;
    }
  }

  if (!context.mounted) return;
  await _pushThread(
    Navigator.of(context, rootNavigator: true),
    conversationId: conversationId,
    peer: peer,
    lang: chatLanguageFor(context),
  );
}

/// Configures the plugin for [conversationId], pushes the thread, and releases
/// the plugin's per-conversation resources when the thread is popped.
Future<void> _pushThread(
  NavigatorState navigator, {
  required String conversationId,
  required ChatUser peer,
  required ChatLanguage lang,
}) async {
  final session = ChatSession.instance;
  await MessengerChat.init(
    transport: DmChatTransport(
      api: session.api,
      conversationId: conversationId,
      myUserId: session.myUserId,
    ),
    me: ChatUser(id: session.myUserId, name: session.myName),
    features: const ChatFeatures.textOnly(),
    lang: lang,
    // Renders shared post/story sentinel messages as rich cards.
    sharedMessageBuilder: buildSharedMessage,
  );

  try {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(peer: peer, lang: lang),
      ),
    );
  } finally {
    await MessengerChat.release();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:treepnet/app/bloc/app_bloc.dart';
import 'package:treepnet/chat/backend/dm_transports.dart';
import 'package:treepnet/chat/chat_session.dart';
import 'package:treepnet/chat/chat_theme.dart';
import 'package:treepnet/chat/chat_thread_screen.dart';
import 'package:treepnet/chat/chat_share_ref.dart';
import 'package:treepnet/chat/shared_message_card.dart';
import 'package:treepnet/l10n/l10n.dart';
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

/// Resolves the current user's real username for the chat backend.
///
/// `AppBloc.state.user` is the AUTH user (id/email) and often has no username —
/// its [User.displayUsername] falls back to "Unknown", which is then what peers
/// see as the sender. The app profile (from the local DB) does carry the
/// username, so fall back to it whenever the auth user's name is missing.
Future<String> currentChatName(UserRepository repo, User me) async {
  final direct = me.displayUsername;
  if (direct.isNotEmpty && direct != 'Unknown') return direct;
  try {
    final profile = await repo.profile(id: me.id).first;
    final resolved = profile.displayUsername;
    if (resolved.isNotEmpty && resolved != 'Unknown') return resolved;
  } catch (_) {
    // Profile not synced yet — keep the fallback; refreshIdentity will retry.
  }
  return direct;
}

/// Maps the app's current locale to the plugin's language enum.
ChatLanguage chatLanguageFor(BuildContext context) {
  // The app ships only Russian + English (locale follows the system / the
  // user's app-language choice); the chat mirrors it — Russian for `ru`,
  // English for everything else. No Uzbek.
  final code = Localizations.localeOf(context).languageCode;
  return code == 'ru' ? ChatLanguage.russian : ChatLanguage.english;
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
  final repo = context.read<UserRepository>();
  final couldNotOpen = context.l10n.couldNotOpenChatText;

  // Blocking no longer prevents OPENING the thread — you can read the history
  // and the composer is replaced by a "blocked" notice inside (see
  // ChatThreadScreen). Only actual sending is gated, app-side.
  final myName = await currentChatName(repo, me);
  ({String conversationId, ChatUser peer}) opened;
  try {
    await session.ensureStarted(
      myUuid: me.id,
      myName: myName,
      myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
    );
    opened = await session.openConversation(
      peerUuid: peerUuid,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
    );
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(couldNotOpen)));
    return;
  }

  await _pushThread(
    navigator,
    conversationId: opened.conversationId,
    peer: opened.peer,
    peerUuid: peerUuid,
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
  final repo = context.read<UserRepository>();
  if (await _blockedEitherWay(context, meId: me.id, peerUuid: peerUuid)) {
    return false;
  }

  final session = ChatSession.instance;
  await session.ensureStarted(
    myUuid: me.id,
    myName: await currentChatName(repo, me),
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
/// the create/find round-trip. The peer's app uuid comes from the list
/// transport (the plugin's [ChatUser] only carries the backend id) so the
/// thread can resolve block state.
Future<void> openConversationScreen(
  BuildContext context, {
  required String conversationId,
  required ChatUser peer,
}) async {
  final session = ChatSession.instance;

  // Guarantee our own backend id is resolved before the thread renders. The
  // plugin decides which side each message sits on (and whether it counts as
  // unread) by comparing that id against the message's sender — so if the
  // session hadn't finished starting (empty id), every message, our own
  // included, would drop onto the peer side. The inbox normally warms the
  // session first, but this closes the race when it hasn't.
  if (session.myUserId.isEmpty) {
    final me = context.read<AppBloc>().state.user;
    if (!me.isAnonymous) {
      final repo = context.read<UserRepository>();
      await session.ensureStarted(
        myUuid: me.id,
        myName: await currentChatName(repo, me),
        myAvatarUrl: me.hasAvatar ? me.avatarUrl : null,
      );
    }
  }
  if (!context.mounted) return;

  final peerUuid = session.isStarted
      ? session.listTransport.peerUuidOf(conversationId)
      : null;

  await _pushThread(
    Navigator.of(context, rootNavigator: true),
    conversationId: conversationId,
    peer: peer,
    peerUuid: peerUuid ?? '',
    lang: chatLanguageFor(context),
  );
}

/// Configures the plugin for [conversationId], pushes the thread, and releases
/// the plugin's per-conversation resources when the thread is popped.
Future<void> _pushThread(
  NavigatorState navigator, {
  required String conversationId,
  required ChatUser peer,
  required String peerUuid,
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
    features: ChatTheme.features,
    lang: lang,
    // Renders shared post/story sentinel messages as rich cards.
    sharedMessageBuilder: buildSharedMessage,
    // Reply quotes / previews show "📷 Post" instead of the raw sentinel.
    sharedReplyPreview: sharedContentPreview,
  );

  try {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          peer: peer,
          peerUuid: peerUuid,
          conversationId: conversationId,
          lang: lang,
        ),
      ),
    );
  } finally {
    await MessengerChat.release();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:messenger_chat/messenger_chat.dart';

import 'package:treepnet/chat/backend/chat_backend_config.dart';
import 'package:treepnet/chat/backend/dm_api.dart';
import 'package:treepnet/chat/backend/dm_transports.dart';

/// One shared connection to the chat backend for the whole app session.
///
/// The inbox ([DmListTransport]) and every open conversation
/// ([DmChatTransport]) reuse the single [DmApi]/socket held here, so the inbox
/// keeps updating in real time while a chat is open. Rebuilt whenever the
/// logged-in user changes; released on logout.
class ChatSession {
  ChatSession._();

  static final ChatSession instance = ChatSession._();

  DmApi? _api;
  DmListTransport? _listTransport;

  /// The app-side profile UUID (`profiles.id`) of the started session.
  String _myUuid = '';

  /// Our backend-side numeric id (from `/chat/dm/me`), compared against a
  /// message's `senderId` to decide which side of the thread it belongs to.
  String _myUserId = '';

  /// Display name of the current user, shown as the "me" side of a thread.
  String _myName = '';

  /// Total unread across all conversations, for the nav-bar badge. Stable
  /// across the session (mirrors the current list transport), so widgets can
  /// bind to it once.
  final ValueNotifier<int> unreadTotal = ValueNotifier<int>(0);
  VoidCallback? _unreadListener;

  DmApi get api => _api!;
  DmListTransport get listTransport => _listTransport!;
  String get myUserId => _myUserId;
  String get myName => _myName;
  bool get isStarted => _api != null;

  /// Whether the session is already connected for [myUuid].
  bool startedFor(String myUuid) => _api != null && _myUuid == myUuid;

  /// Ensures the backend connection is up for the given user. Idempotent for
  /// the same user; switches connection if the user changed.
  Future<void> ensureStarted({
    required String myUuid,
    required String myName,
    String? myAvatarUrl,
  }) async {
    if (startedFor(myUuid)) {
      // Already connected for this user. The first call often comes from the
      // nav bar at startup, before the profile username has synced — so a later
      // call (opening the inbox / a chat) may carry the real username. Push it
      // through so the peer stops seeing "Unknown".
      if (myName.isNotEmpty && myName != 'Unknown' && myName != _myName) {
        _myName = myName;
      }
      _api?.refreshIdentity(name: myName, avatar: myAvatarUrl);
      return;
    }
    await stop();

    final deviceId = await MessengerChat.getDeviceId();
    final api = DmApi(
      baseUrl: chatBaseUrl,
      myUuid: myUuid,
      appName: chatAppName,
      apiKey: chatApiKey,
      deviceId: deviceId,
      // x-device-name is mandatory server-side and must not be 'unknown'.
      deviceName: 'TreepNet ${Platform.operatingSystem}',
      userName: myName,
      userAvatar: myAvatarUrl,
    );

    // Our backend numeric id — the middleware auto-creates/updates our row.
    final me = await api.dio.get<Map<String, dynamic>>('/chat/dm/me');
    _myUserId = me.data?['id']?.toString() ?? '';
    _myUuid = myUuid;
    _myName = myName;
    _api = api;
    final list = DmListTransport(api: api, myUserId: _myUserId);
    _listTransport = list;

    // Mirror the transport's unread into the stable session notifier.
    _unreadListener = () => unreadTotal.value = list.unreadTotal.value;
    list.unreadTotal.addListener(_unreadListener!);

    // Warm up in the background so the badge is populated and real-time
    // updates arrive app-wide, even before the inbox is opened. Best-effort.
    unawaited(_warmUp(list));
    unawaited(_registerPushToken());
  }

  StreamSubscription<String>? _tokenRefreshSub;

  /// Registers this device's FCM token with the chat backend so messages push
  /// while the app is closed. Best-effort — push just won't work if it fails.
  Future<void> _registerPushToken() async {
    try {
      final platform = Platform.operatingSystem;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _api?.registerDeviceToken(token: token, platform: platform);
      }
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        unawaited(
          _api?.registerDeviceToken(token: t, platform: platform) ??
              Future<void>.value(),
        );
      });
    } catch (_) {
      // Firebase not configured on this build / no APNs token yet — ignore.
    }
  }

  Future<void> _warmUp(DmListTransport list) async {
    try {
      await list.connect();
      await list.loadConversations(page: 1, size: 50);
    } catch (_) {
      // Badge stays at its last value; the inbox will retry on open.
    }
  }

  /// Opens (or finds) the 1:1 conversation with [peerUuid] and returns its id
  /// plus the resolved peer (carrying the backend numeric id used for
  /// sender/presence matching). [peerName]/[peerAvatarUrl] seed the peer's row
  /// when they haven't opened chat yet (cold-start).
  Future<({String conversationId, ChatUser peer})> openConversation({
    required String peerUuid,
    required String peerName,
    String? peerAvatarUrl,
  }) async {
    final response = await api.dio.post<Map<String, dynamic>>(
      '/chat/dm/conversations',
      data: {
        'peerUuid': peerUuid,
        'peerName': peerName,
        if (peerAvatarUrl != null && peerAvatarUrl.isNotEmpty)
          'peerAvatar': peerAvatarUrl,
      },
    );

    final id = response.data?['id']?.toString() ?? '';
    final peerJson = response.data?['peer'] as Map?;
    final resolvedAvatar = peerJson?['avatar']?.toString();
    // Prefer the app-supplied username (always passed from the caller) over the
    // backend's stored name: a peer who has never opened chat has a cold-start
    // row that can read "Unknown" or a stale full name. We know the real
    // username here, so the thread header always shows it.
    final backendName = peerJson?['name']?.toString() ?? '';
    final peer = ChatUser(
      id: peerJson?['id']?.toString() ?? '',
      name: peerName.isNotEmpty ? peerName : backendName,
      avatarUrl: (resolvedAvatar != null && resolvedAvatar.isNotEmpty)
          ? resolvedAvatar
          : peerAvatarUrl,
      // Seed the peer's live status from the REST payload — otherwise the
      // header shows "offline" until the peer happens to toggle presence
      // (they could already be online before we opened the chat).
      isOnline: peerJson?['isOnline'] == true,
      lastSeen: DateTime.tryParse(peerJson?['lastSeen']?.toString() ?? ''),
    );
    return (conversationId: id, peer: peer);
  }

  /// Sends a one-off text message to [peerUuid] without opening the thread UI
  /// (used by share / story-reply). Opens/creates the conversation, ensures the
  /// socket is up, then emits. The conversation surfaces in the peer's inbox.
  Future<void> sendText({
    required String peerUuid,
    required String peerName,
    required String text,
    String? peerAvatarUrl,
  }) async {
    final opened = await openConversation(
      peerUuid: peerUuid,
      peerName: peerName,
      peerAvatarUrl: peerAvatarUrl,
    );
    await api.connect();
    api.send(
      conversationId: opened.conversationId,
      content: text,
      contentType: 'text',
      key: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  /// Tears down the connection (logout / user switch).
  Future<void> stop() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    final listener = _unreadListener;
    if (listener != null) {
      _listTransport?.unreadTotal.removeListener(listener);
      _unreadListener = null;
    }
    await _listTransport?.dispose();
    _listTransport = null;
    _api = null;
    _myUuid = '';
    _myUserId = '';
    _myName = '';
    unreadTotal.value = 0;
  }
}

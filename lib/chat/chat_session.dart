import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:messenger_chat/messenger_chat.dart';
import 'package:token_storage/token_storage.dart';

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

  /// Closes the socket in the background (see [_onPause]) and reloads the
  /// inbox when the app comes back after a while (see [_onResume]).
  AppLifecycleListener? _lifecycle;
  DateTime? _backgroundedAt;
  Timer? _pauseTimer;

  DmApi get api => _api!;
  DmListTransport get listTransport => _listTransport!;
  String get myUserId => _myUserId;
  String get myName => _myName;
  bool get isStarted => _api != null;

  /// Whether the session is already connected for [myUuid].
  bool startedFor(String myUuid) => _api != null && _myUuid == myUuid;

  /// The user [ensureStarted] was last asked for, so a failed start can be
  /// retried. Cleared by [stop].
  ({String uuid, String name, String? avatar})? _wanted;

  /// The start in flight, if any.
  Future<void>? _starting;

  /// Bumped by [stop], so a start still in flight from before a logout closes
  /// its connection instead of bringing the session back.
  int _generation = 0;

  Timer? _retryTimer;
  int _retryAttempt = 0;

  /// Ensures the backend connection is up for the given user. Idempotent for
  /// the same user; switches connection if the user changed.
  ///
  /// One start at a time: the nav bar and the inbox both start the session as
  /// the app opens, and on a slow connection both used to get past the
  /// started-check and open a connection each — the first was overwritten,
  /// never closed, and kept the account online after logout. A second caller
  /// now waits for the first. A start that fails (no connection) is retried by
  /// the session itself, and at once when the app comes back to the front.
  Future<void> ensureStarted({
    required String myUuid,
    required String myName,
    String? myAvatarUrl,
  }) async {
    _wanted = (uuid: myUuid, name: myName, avatar: myAvatarUrl);
    _lifecycle ??= AppLifecycleListener(
      onHide: () => _backgroundedAt = DateTime.now(),
      onPause: _onPause,
      onShow: _onResume,
    );
    while (_starting != null) {
      await _starting!.catchError((Object _) {});
    }
    // Logged out, or someone else signed in, while this call waited: it must
    // not bring the old account's connection back.
    if (_wanted?.uuid != myUuid) return;
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
    final start = _start(
      myUuid: myUuid,
      myName: myName,
      myAvatarUrl: myAvatarUrl,
    ).whenComplete(() => _starting = null);
    _starting = start;
    try {
      await start;
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryAttempt = 0;
    } catch (_) {
      _scheduleRetry();
      rethrow;
    }
  }

  /// Tries a failed start again after 5, 10, 20, 30, then every 60 seconds.
  void _scheduleRetry() {
    if (_wanted == null) return;
    const delays = [5, 10, 20, 30, 60];
    final seconds = delays[_retryAttempt.clamp(0, delays.length - 1)];
    _retryAttempt++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: seconds), _retryNow);
  }

  void _retryNow() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final wanted = _wanted;
    if (wanted == null || startedFor(wanted.uuid) || _starting != null) return;
    // In the background it waits: coming back to the front retries (see
    // [_onResume]).
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    unawaited(
      ensureStarted(
        myUuid: wanted.uuid,
        myName: wanted.name,
        myAvatarUrl: wanted.avatar,
      ).catchError((Object _) {}),
    );
  }

  Future<void> _start({
    required String myUuid,
    required String myName,
    String? myAvatarUrl,
  }) async {
    final generation = _generation;
    await _teardown();

    final deviceId = await MessengerChat.getDeviceId();
    final api = DmApi(
      baseUrl: chatBaseUrl,
      myUuid: myUuid,
      appName: chatAppName,
      apiKey: chatApiKey,
      deviceId: deviceId,
      // x-device-name is mandatory server-side and must not be 'unknown'.
      deviceName: 'TreepNet ${Platform.operatingSystem}',
      lang: _lang,
      idToken: ({forceRefresh = false}) =>
          _idTokenFor(myUuid, forceRefresh: forceRefresh),
      userName: myName,
      userAvatar: myAvatarUrl,
    );

    // Our backend numeric id — the middleware auto-creates/updates our row.
    final Map<String, dynamic>? me;
    try {
      me = (await api.dio.get<Map<String, dynamic>>('/chat/dm/me')).data;
    } catch (_) {
      await api.dispose();
      rethrow;
    }
    if (generation != _generation) {
      // Logged out meanwhile.
      await api.dispose();
      return;
    }
    _myUserId = me?['id']?.toString() ?? '';
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

  /// The current Firebase ID token, refreshed first when it is about to expire
  /// (or when [forceRefresh]). Only a token for [myUuid] is returned: the chat
  /// backend takes our identity from it.
  static Future<String?> _idTokenFor(
    String myUuid, {
    bool forceRefresh = false,
  }) async {
    final session = EntraSession.instance;
    var tokens = session.current;
    if (tokens == null) return null;
    if (forceRefresh || !tokens.isIdTokenValid) {
      await session.refresh().timeout(const Duration(seconds: 10));
      tokens = session.current;
    }
    // An empty token: the app opened offline and none has come yet.
    if (tokens == null || tokens.userId != myUuid) return null;
    if (tokens.idToken.isEmpty) return null;
    return tokens.idToken;
  }

  /// In the background the socket is closed, so the backend sends new
  /// messages as push notifications instead of over a socket nobody reads.
  /// Android keeps the app running a while, so a quick switch away and back
  /// keeps the connection; iOS suspends the app almost at once (a timer would
  /// never fire), so it closes right away.
  void _onPause() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(
      Platform.isIOS ? Duration.zero : const Duration(seconds: 10),
      () => _api?.pause(),
    );
  }

  /// Back in the foreground: reconnect if the socket was closed, and after at
  /// least 30 s away reload the inbox — messages may have arrived while it
  /// wasn't listening (throttled in [DmListTransport.refresh]).
  void _onResume() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
    if (_api == null) {
      // Not started (no connection earlier): try now.
      _retryNow();
      return;
    }
    _api?.resume();
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null ||
        DateTime.now().difference(since) < const Duration(seconds: 30)) {
      return;
    }
    unawaited(_listTransport?.refresh() ?? Future<void>.value());
  }

  /// App language for chat pushes (see [setLanguage]).
  String _lang = 'en';

  /// The app language changed (or is first known): chat push notifications
  /// follow it.
  void setLanguage(String lang) {
    _lang = lang;
    _api?.setLanguage(lang);
  }

  /// Stops chat pushes to this device for the signed-in user — call on
  /// sign-out, before the FCM token itself is deleted. Best-effort.
  Future<void> unregisterPushToken() async {
    final api = _api;
    if (api == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await api.unregisterDeviceToken(token);
      }
    } catch (_) {
      // Firebase not configured, or offline: the FCM token is deleted anyway.
    }
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
      _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
        t,
      ) {
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
  /// socket is up, then sends and waits for the backend to confirm it; throws
  /// when it doesn't. The conversation surfaces in the peer's inbox.
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
    final result = await api.send(
      conversationId: opened.conversationId,
      content: text,
      contentType: 'text',
      key: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    if (!result.ok) throw StateError('Message not sent: ${result.error}');
  }

  /// Tears down the connection on logout; a start still in flight closes its
  /// own when it finishes, and failed starts are no longer retried.
  Future<void> stop() async {
    _generation++;
    _wanted = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _lifecycle?.dispose();
    _lifecycle = null;
    await _teardown();
  }

  /// Closes the current connection (also before switching user).
  Future<void> _teardown() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _backgroundedAt = null;
    _pauseTimer?.cancel();
    _pauseTimer = null;
    final listener = _unreadListener;
    if (listener != null) {
      _listTransport?.unreadTotal.removeListener(listener);
      _unreadListener = null;
    }
    await _listTransport?.dispose();
    _listTransport = null;
    // Actually close the socket — only here: the session owns `api`
    // (DmListTransport.dispose() leaves it alone). Without this the previous
    // user's websocket stayed connected (authenticated as them) after logout /
    // account switch and crossed wires with the next user's session.
    await _api?.dispose();
    _api = null;
    _myUuid = '';
    _myUserId = '';
    _myName = '';
    unreadTotal.value = 0;
  }
}
